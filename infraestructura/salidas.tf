output "region" {
  description = "Región donde se crearon los recursos."
  value       = var.region
}

output "bucket" {
  description = "Nombre del bucket S3 privado."
  value       = aws_s3_bucket.datos.bucket
}

output "ubicacion_datos" {
  description = "Prefijo de S3 con los CSV de entregas."
  value       = local.ubicacion_datos
}

output "ubicacion_resultados_athena" {
  description = "Prefijo de S3 donde Athena guarda los resultados."
  value       = local.ubicacion_resultados
}

output "base_datos" {
  description = "Base de datos de Glue Data Catalog."
  value       = aws_glue_catalog_database.entregas.name
}

output "tabla" {
  description = "Tabla externa con partition projection."
  value       = aws_glue_catalog_table.entregas.name
}

output "tabla_completa" {
  description = "Nombre calificado para usar en Athena."
  value       = "${aws_glue_catalog_database.entregas.name}.${aws_glue_catalog_table.entregas.name}"
}

output "workgroup" {
  description = "Workgroup de Athena donde se ejecutan las consultas."
  value       = aws_athena_workgroup.entregas.name
}
