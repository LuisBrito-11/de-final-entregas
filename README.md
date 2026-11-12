# Entregas de mensajería con S3, Glue (partition projection) y Athena

Examen final de Arquitecturas de Datos 2026-2 (Universidad EIA), punto 1.
Estudiante: Luis Miguel Brito Rincón.

Enunciado: <https://github.com/smm-0216/DE-Final-Entregas>.

> Este README se completa a medida que avanza el ejercicio. Cada etapa queda en su propio commit.

## Prerrequisitos

| Herramienta | Versión usada | Para qué |
| --- | --- | --- |
| Terraform | 1.16.2 | Crear y eliminar la infraestructura (`infraestructura/`). |
| AWS CLI v2 | 2.36.48 | Subir los CSV, ejecutar las consultas de Athena y verificar recursos. |
| Git y Git Bash | 2.x | Control de versiones y terminal (Windows). |

- Credenciales de AWS configuradas en el perfil por defecto de la AWS CLI (`aws configure`). No se guardan en el repositorio.
- Región: **us-east-2 (Ohio)**.
- Cuenta compartida del curso: todos los recursos llevan el prefijo `de-gr02-user-4-` (en Glue, `de_gr02_user_4_`).
- Permisos necesarios: S3 (crear bucket, bloqueo de acceso público, subir y leer objetos), Glue (base y tabla), Athena (workgroup y consultas).

## Estructura

```text
.
├── README.md
├── .gitignore               # excluye credenciales, *.tfstate* y .terraform/
├── .gitattributes           # fuerza LF; los CSV no se convierten nunca
├── data/entregas/           # CSV suministrados (sin modificar)
├── resultados_esperados/    # referencias suministradas (sin modificar)
├── infraestructura/         # Terraform: principal.tf, variables.tf, salidas.tf
├── consultas/               # SQL de Athena
├── resultados/inicial/      # resultados de Athena con los días 1 y 2
├── resultados/final/        # resultados de Athena con los tres días
├── evidencias/              # apply, outputs, ejecuciones de Athena y destroy
└── respuestas.md            # preguntas conceptuales
```

## Finales de línea

Los CSV suministrados usan LF. En Windows, `core.autocrlf=true` los convertiría a CRLF al extraerlos y Athena leería `duracion_minutos` como `20\r` (NULL). Por eso `.gitattributes` marca los CSV como `-text` y, antes de cada subida a S3, se comprueba que `git hash-object --no-filters <archivo>` coincide con el blob del repositorio del profesor.
