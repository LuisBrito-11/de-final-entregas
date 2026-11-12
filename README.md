# Entregas de mensajería con S3, Glue (partition projection) y Athena

Examen final de Arquitecturas de Datos 2026-2 (Universidad EIA), punto 1.
Estudiante: Luis Miguel Brito Rincón.
Enunciado: <https://github.com/smm-0216/DE-Final-Entregas>.

Los CSV diarios de intentos de entrega se guardan en S3, una tabla externa de Glue Data Catalog los describe con **partition projection** sobre `fecha` y Athena los consulta y escribe sus resultados en otro prefijo del mismo bucket. Una fecha nueva se incorpora **solo subiendo su archivo**: no hay crawlers, `MSCK REPAIR TABLE`, `ALTER TABLE ADD PARTITION` ni particiones creadas con Terraform.

```text
data/entregas/fecha=…/entregas.csv ──aws s3 cp──▶ s3://<bucket>/entregas/fecha=…/entregas.csv
                                                        │
                       Glue: de_gr02_user_4_entregas.entregas (projection.fecha: 2026-10-01..2026-10-03)
                                                        │
                       Athena, workgroup de-gr02-user-4-entregas ──▶ s3://<bucket>/resultados-athena/
```

## 1. Prerrequisitos

| Herramienta | Versión usada | Para qué |
| --- | --- | --- |
| Terraform | 1.16.2 (proveedor `hashicorp/aws` 6.x, fijado en `.terraform.lock.hcl`) | Crear y eliminar la infraestructura. |
| AWS CLI v2 | 2.36.48 | Subir los CSV, ejecutar consultas de Athena, descargar resultados y verificar. |
| Git Bash (Windows) o una terminal Bash | — | Ejecutar los comandos de este README. |

- Credenciales de AWS en el perfil por defecto de la AWS CLI (`aws configure`). **No** se guardan en el repositorio.
- Región: **us-east-2 (Ohio)**. Cuenta del curso 802655955683, usuario IAM `de-gr02-user-4`.
- La cuenta es compartida: todos los recursos llevan el prefijo `de-gr02-user-4-` (en Glue, `de_gr02_user_4_`).
- Permisos usados: S3 (bucket, bloqueo de acceso público, cifrado, propiedad de objetos, objetos), Glue (base y tabla), Athena (workgroup y consultas).

### Finales de línea (importante en Windows)

Los CSV suministrados usan LF. Si se extraen con `core.autocrlf=true` quedan con CRLF y Athena lee `duracion_minutos` como `20\r` (NULL). Por eso `.gitattributes` marca los CSV como `-text` (git nunca los convierte) y, antes de cada subida, se comprobó que `git hash-object --no-filters <archivo>` coincide con el blob del repositorio del profesor. Después de cada subida se comprobó que el ETag del objeto en S3 es igual al MD5 del archivo local.

## 2. Configuración

Variables de [`infraestructura/variables.tf`](infraestructura/variables.tf) (todas tienen valor por defecto; para cambiarlas se usa `-var nombre=valor`):

| Variable | Valor por defecto | Descripción |
| --- | --- | --- |
| `region` | `us-east-2` | Región de AWS. |
| `nombre_bucket` | `de-gr02-user-4-entregas-examen` | Bucket S3 privado (nombre global único). |
| `nombre_base_datos` | `de_gr02_user_4_entregas` | Base de datos de Glue. |
| `nombre_tabla` | `entregas` | Tabla externa. |
| `nombre_workgroup` | `de-gr02-user-4-entregas` | Workgroup de Athena. |
| `prefijo_datos` | `entregas` | Prefijo de los CSV. |
| `prefijo_resultados_athena` | `resultados-athena` | Prefijo de los resultados de Athena. |
| `fecha_inicio_proyeccion` / `fecha_fin_proyeccion` | `2026-10-01` / `2026-10-03` | Rango proyectado, ambos extremos incluidos. |

## 3. Infraestructura (Terraform)

[`infraestructura/principal.tf`](infraestructura/principal.tf) crea:

1. **Bucket S3 privado** `de-gr02-user-4-entregas-examen` con bloqueo total de acceso público, propiedad de objetos `BucketOwnerEnforced` (sin ACL) y cifrado SSE-S3. Los prefijos `entregas/` y `resultados-athena/` son parte de las claves; no se crean carpetas.
2. **Base de datos de Glue** `de_gr02_user_4_entregas`.
3. **Tabla externa** `entregas`:
   - Columnas en el orden del diccionario: `id_envio string`, `ciudad string`, `transportadora string`, `estado string`, `duracion_minutos int`.
   - `LazySimpleSerDe` con `field.delim = ","` y `skip.header.line.count = 1`.
   - `fecha string` como **clave de partición**, separada de las cinco columnas.
   - Proyección: `projection.enabled = true`, `projection.fecha.type = date`, `projection.fecha.format = yyyy-MM-dd`, `projection.fecha.range = 2026-10-01,2026-10-03`, `projection.fecha.interval = 1`, `projection.fecha.interval.unit = DAYS`.
   - `storage.location.template = s3://de-gr02-user-4-entregas-examen/entregas/fecha=${fecha}/` (prefijo de la partición, terminado en `/`). En HCL se escribe `$${fecha}` para que Terraform no lo interpole; después del `apply` se comprobó con `aws glue get-table` que la propiedad contiene literalmente `${fecha}` ([`evidencias/glue_tabla_tras_apply.json`](evidencias/glue_tabla_tras_apply.json)).
4. **Workgroup de Athena** `de-gr02-user-4-entregas` con resultados en `s3://de-gr02-user-4-entregas-examen/resultados-athena/`, `enforce_workgroup_configuration = true` (ninguna consulta puede escribir en otro lugar) y `force_destroy = true` (el `destroy` no falla por el historial de consultas).

[`infraestructura/salidas.tf`](infraestructura/salidas.tf) expone `bucket`, `base_datos`, `tabla`, `tabla_completa`, `workgroup`, `region` y las dos ubicaciones de S3.

### Despliegue

```bash
cd infraestructura
# Opcional en Windows/OneDrive: mantener el proveedor fuera de la carpeta sincronizada.
export TF_DATA_DIR="$HOME/tfdata/de-final-entregas"
terraform init
terraform fmt -check
terraform validate
terraform plan -out "$TF_DATA_DIR/plan.tfplan"
terraform apply "$TF_DATA_DIR/plan.tfplan"      # evidencia: evidencias/aplicacion_terraform.txt
terraform output -json > ../evidencias/outputs.json
```

El archivo `terraform.tfstate` queda en `infraestructura/` y está excluido por `.gitignore` (igual que `.terraform/` y las credenciales).

## 4. Carga de datos en dos etapas

Cada archivo se sube con su propio `aws s3 cp` (no se usa `sync` ni `--recursive`). `B=de-gr02-user-4-entregas-examen`.

**Etapa inicial: solo días 1 y 2.**

```bash
aws s3 cp "data/entregas/fecha=2026-10-01/entregas.csv" "s3://$B/entregas/fecha=2026-10-01/entregas.csv"
aws s3 cp "data/entregas/fecha=2026-10-02/entregas.csv" "s3://$B/entregas/fecha=2026-10-02/entregas.csv"
```

**Etapa final: día 3**, solo después de guardar y subir a GitHub los resultados iniciales y sin tocar la infraestructura:

```bash
aws s3 cp "data/entregas/fecha=2026-10-03/entregas.csv" "s3://$B/entregas/fecha=2026-10-03/entregas.csv"
```

Listados del bucket como evidencia: [`listado_bucket_0_vacio.txt`](evidencias/listado_bucket_0_vacio.txt) → [`listado_bucket_1_dias_1_y_2.txt`](evidencias/listado_bucket_1_dias_1_y_2.txt) → [`listado_bucket_2_dia_3.txt`](evidencias/listado_bucket_2_dia_3.txt). Los `resultados_esperados/` nunca se subieron a S3.

## 5. Ejecución de consultas

Todas las consultas se ejecutan en el workgroup `de-gr02-user-4-entregas`. Athena ejecuta **una sentencia por ejecución**, así que las tres sentencias de `verificacion_tercer_dia.sql` se lanzaron por separado. Para cada sentencia:

```bash
WG=de-gr02-user-4-entregas; DB=de_gr02_user_4_entregas
SQL=$(grep -v '^ *--' consultas/intentos_por_fecha_estado.sql | sed 's/;[[:space:]]*$//')
QID=$(aws athena start-query-execution --work-group "$WG" \
        --query-execution-context Database="$DB" --query-string "$SQL" \
        --query QueryExecutionId --output text)
aws athena get-query-execution --query-execution-id "$QID" \
    --query QueryExecution.Status.State --output text          # repetir hasta SUCCEEDED
aws athena get-query-execution --query-execution-id "$QID" > "evidencias/athena_crudo/$QID.json"
aws s3 cp "s3://$B/resultados-athena/$QID.csv" "evidencias/athena_crudo/$QID.csv"
sed 's/"//g' "evidencias/athena_crudo/$QID.csv" | tr -d '\r' > resultados/inicial/intentos_por_fecha_estado.csv
echo "inicial,consultas/intentos_por_fecha_estado.sql,$QID,resultados/inicial/intentos_por_fecha_estado.csv" >> evidencias/ejecuciones_athena.csv
```

**Normalización de resultados.** Athena escribe su CSV con todos los campos entre comillas (`"2026-10-01","entregado","3"`). El archivo real descargado de `resultados-athena/` se guarda **sin modificar** en [`evidencias/athena_crudo/<id_ejecucion>.csv`](evidencias/athena_crudo/), junto con el detalle de la ejecución (`<id_ejecucion>.json`: SQL, workgroup, ubicación de salida y bytes escaneados). El archivo de `resultados/` se obtiene de ese CSV quitando **solo** las comillas y asegurando LF; los valores no contienen comas ni comillas, así que no cambia ningún dato.

### Consultas

| Archivo | Qué hace |
| --- | --- |
| [`consultas/intentos_por_fecha_estado.sql`](consultas/intentos_por_fecha_estado.sql) | `count(*)` por `fecha` y `estado`, ordenado por fecha y estado ascendentes. Sin filtro de fechas. |
| [`consultas/porcentaje_exito_por_fecha_ciudad.sql`](consultas/porcentaje_exito_por_fecha_ciudad.sql) | `100 × entregados / total de intentos` por fecha y ciudad. Se convierte a `double` antes de dividir (en Trino `100.0` es un `DECIMAL` de escala 1 y daría `66.7`) y al final `cast(... as decimal(5,2))` para mostrar siempre dos decimales. Sin filtro de fechas. |
| [`consultas/duracion_promedio_2026-10-02.sql`](consultas/duracion_promedio_2026-10-02.sql) | Promedio de `duracion_minutos` solo con `estado = 'entregado'` y `fecha = '2026-10-02'`, como `decimal(10,2)`. |
| [`consultas/verificacion_tercer_dia.sql`](consultas/verificacion_tercer_dia.sql) | Tres sentencias: los seis registros del 2026-10-03, sus conteos por estado y el total de la tabla. |

Las dos consultas agregadas no filtran fechas, así que el mismo SQL sirvió sin cambios para la etapa inicial y la final.

### Comparación con las referencias

```bash
cmp resultados/inicial/intentos_por_fecha_estado.csv          resultados_esperados/intentos_por_fecha_estado_inicial.csv
cmp resultados/inicial/porcentaje_exito_por_fecha_ciudad.csv  resultados_esperados/porcentaje_exito_por_fecha_ciudad_inicial.csv
cmp resultados/inicial/duracion_promedio_2026-10-02.csv       resultados_esperados/duracion_promedio_2026-10-02.csv
cmp resultados/final/intentos_por_fecha_estado.csv            resultados_esperados/intentos_por_fecha_estado_final.csv
cmp resultados/final/porcentaje_exito_por_fecha_ciudad.csv    resultados_esperados/porcentaje_exito_por_fecha_ciudad_final.csv
```

Los cinco pares son **idénticos byte a byte** (`cmp` sin salida).

## 6. Resultados y ejecuciones

[`evidencias/ejecuciones_athena.csv`](evidencias/ejecuciones_athena.csv) (columnas `etapa,archivo_sql,id_ejecucion,archivo_resultado`, rutas relativas a la raíz):

| Etapa | Consulta | Id de ejecución | Resultado |
| --- | --- | --- | --- |
| inicial | `intentos_por_fecha_estado.sql` | `022723fb-e5ce-4152-89ab-afc897107a3e` | 6 filas, igual a la referencia inicial |
| inicial | `porcentaje_exito_por_fecha_ciudad.sql` | `55dde145-fe22-478b-9b83-ac259516b648` | 4 filas, igual a la referencia inicial |
| inicial | `duracion_promedio_2026-10-02.sql` | `4a12c1d3-89bf-47e9-b49a-12d2f8744969` | `2026-10-02,36.67` |
| final | `verificacion_tercer_dia.sql` (1) | `c65674f4-197f-4297-9350-26ba61556520` | Los 6 registros del 2026-10-03 |
| final | `verificacion_tercer_dia.sql` (2) | `27d58e30-e765-4d15-9431-1622e9da3f57` | 3 `destinatario_ausente`, 1 `direccion_incorrecta`, 2 `entregado` |
| final | `verificacion_tercer_dia.sql` (3) | `e9a046d4-b9df-423e-9b76-712889b98af0` | `total_registros = 18` |
| final | `intentos_por_fecha_estado.sql` | `efe6fbeb-506b-461c-8f1e-d1aa162da293` | 9 filas, igual a la referencia final |
| final | `porcentaje_exito_por_fecha_ciudad.sql` | `d0250d45-d373-46b3-b303-7969497d1fa3` | 6 filas, igual a la referencia final |

Comprobación adicional antes del día 3 (registrada aparte en [`evidencias/verificaciones_adicionales_athena.csv`](evidencias/verificaciones_adicionales_athena.csv) para no mezclarla con las consultas pedidas): `a934d421-ae79-4efd-8c06-a8e8a9b37685` devolvió `total_registros = 12`, `registros_2026_10_03 = 0`, `fechas_con_datos = 2` ([`evidencias/compuertas/`](evidencias/compuertas/)).

La consulta del promedio escaneó 313 bytes (solo el archivo del 2 de octubre) y las demás 626 bytes (los dos archivos): el filtro sobre la columna de partición limita lo que Athena lee.

## 7. Incorporación del día 3

1. Se guardaron y subieron a GitHub los resultados iniciales (commit "Etapa inicial").
2. Se guardó el estado de Glue: [`particiones_glue_antes_dia3.json`](evidencias/particiones_glue_antes_dia3.json) (`"Partitions": []`) y [`glue_tabla_antes_dia3.json`](evidencias/glue_tabla_antes_dia3.json).
3. Se subió **solo** `fecha=2026-10-03/entregas.csv` con un `aws s3 cp`.
4. Se ejecutaron las tres sentencias de verificación y se repitieron las dos consultas agregadas (etapa `final`).
5. Se volvió a consultar Glue: [`particiones_glue_despues_dia3.json`](evidencias/particiones_glue_despues_dia3.json) sigue vacío y [`glue_tabla_despues_dia3.json`](evidencias/glue_tabla_despues_dia3.json) es idéntico al de antes (misma `VersionId` 0 y mismas propiedades). No hubo crawlers, `MSCK REPAIR TABLE`, `ALTER TABLE ADD PARTITION` ni cambios de Terraform.

## 8. Limpieza

Primero se guardaron y subieron todas las evidencias. Después:

```bash
# 1. Vaciar el bucket (datos y resultados de Athena)
aws s3 rm "s3://$B/" --recursive
aws s3api list-object-versions --bucket "$B"        # sin versiones (el versionado nunca se activó)

# 2. Eliminar todos los recursos con Terraform
cd infraestructura
terraform plan -destroy
terraform destroy -auto-approve                     # evidencia: evidencias/eliminacion_terraform.txt

# 3. Verificar que no queda nada
aws s3api head-bucket --bucket "$B"                                   # 404 Not Found
aws glue get-database --name de_gr02_user_4_entregas                  # EntityNotFoundException
aws athena get-work-group --work-group de-gr02-user-4-entregas        # InvalidRequestException
```

La salida de estos pasos está en [`evidencias/eliminacion_terraform.txt`](evidencias/eliminacion_terraform.txt).

## 9. Estructura del repositorio

```text
.
├── README.md
├── .gitignore                 # credenciales, *.tfstate*, .terraform/
├── .gitattributes             # LF; los CSV se tratan como binarios
├── data/entregas/             # CSV suministrados (sin modificar)
├── resultados_esperados/      # referencias suministradas (sin modificar)
├── infraestructura/           # principal.tf, variables.tf, salidas.tf, .terraform.lock.hcl
├── consultas/                 # las cuatro consultas SQL
├── resultados/
│   ├── inicial/               # 3 resultados con los días 1 y 2
│   └── final/                 # 2 agregados + verificacion_tercer_dia*.csv
├── evidencias/
│   ├── aplicacion_terraform.txt, outputs.json, ejecuciones_athena.csv, eliminacion_terraform.txt
│   ├── athena_crudo/          # CSV y JSON originales de cada ejecución de Athena
│   ├── compuertas/            # control de 12 registros antes del día 3
│   ├── glue_tabla_*.json, particiones_glue_*.json
│   └── listado_bucket_*.txt
└── respuestas.md
```
