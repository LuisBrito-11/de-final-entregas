# Respuestas conceptuales

## 1. ¿Por qué se pudo consultar el tercer día sin registrar una partición nueva?

Porque mi tabla no depende de una lista de particiones guardada en el catálogo: tiene partition projection activada. Lo comprobé en las propiedades de la tabla (`evidencias/glue_tabla_tras_apply.json`), donde quedaron `projection.enabled = true`, el tipo `date` con formato `yyyy-MM-dd`, el rango `2026-10-01,2026-10-03` con intervalo de un día y la plantilla `s3://de-gr02-user-4-entregas-examen/entregas/fecha=${fecha}/`. Con esas reglas, cada vez que ejecuto una consulta Athena genera las fechas posibles del rango y, para cada una, arma la ruta reemplazando `${fecha}` en la plantilla. Después lee los archivos que haya en esos prefijos.

El 2026-10-03 ya estaba dentro del rango desde el `apply` inicial. Antes de subir mi archivo, la proyección ya apuntaba a `.../fecha=2026-10-03/`, pero ese prefijo estaba vacío, y por eso la compuerta inicial devolvió 12 registros y 0 de ese día (ejecución `a934d421-...`). Cuando subí el CSV, la siguiente consulta encontró el objeto en ese prefijo y aparecieron los seis registros del día y el total de 18 (ejecuciones `c65674f4-...` y `e9a046d4-...`).

La prueba de que no se registró ninguna partición es que `aws glue get-partitions` devolvió `"Partitions": []` tanto antes como después de subir el día 3, y que la tabla siguió en la versión 0 con las mismas propiedades (`glue_tabla_antes_dia3.json` y `glue_tabla_despues_dia3.json` son iguales). Lo único que cambió fue el contenido del bucket, porque yo solo subí el archivo.

## 2. Si se subiera un archivo para el 4 de octubre manteniendo la configuración actual, ¿qué resultado se esperaría y qué se debería modificar para incluirlo?

El archivo quedaría guardado en S3, pero Athena no lo leería. El rango que configuré termina en `2026-10-03`, así que Athena nunca genera el valor `2026-10-04` ni construye la ruta `.../fecha=2026-10-04/`. Las consultas no darían error: seguirían devolviendo los mismos 18 registros y las mismas filas agregadas, y una consulta con `WHERE fecha = '2026-10-04'` devolvería cero filas. Es decir, el dato existiría pero quedaría invisible, sin ningún aviso.

Para incluirlo cambiaría la regla de proyección, no registraría una partición: ampliaría `projection.fecha.range` en Terraform (por ejemplo, `fecha_fin_proyeccion = "2026-10-04"`) y haría `terraform apply`, que solo actualiza las propiedades de la tabla. Otra opción, para no tener que tocarlo cada día, sería usar un rango relativo como `2026-10-01,NOW`, que Athena evalúa en el momento de la consulta. En ambos casos el archivo tendría que respetar la ruta `entregas/fecha=2026-10-04/entregas.csv` y el mismo esquema de cinco columnas.
