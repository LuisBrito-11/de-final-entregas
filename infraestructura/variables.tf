variable "region" {
  description = "Región de AWS donde se crean todos los recursos."
  type        = string
  default     = "us-east-2"
}

variable "nombre_bucket" {
  description = "Nombre global y único del bucket S3 privado (datos en entregas/ y resultados en resultados-athena/)."
  type        = string
  default     = "de-gr02-user-4-entregas-examen"
}

variable "nombre_base_datos" {
  description = "Nombre de la base de datos de Glue Data Catalog (solo minúsculas, números y guion bajo)."
  type        = string
  default     = "de_gr02_user_4_entregas"
}

variable "nombre_tabla" {
  description = "Nombre de la tabla externa con los intentos de entrega."
  type        = string
  default     = "entregas"
}

variable "nombre_workgroup" {
  description = "Nombre del workgroup de Athena donde se ejecutan todas las consultas del ejercicio."
  type        = string
  default     = "de-gr02-user-4-entregas"
}

variable "prefijo_datos" {
  description = "Prefijo de S3 con los CSV, organizado en carpetas fecha=yyyy-MM-dd."
  type        = string
  default     = "entregas"
}

variable "prefijo_resultados_athena" {
  description = "Prefijo de S3 donde Athena escribe los resultados de las consultas."
  type        = string
  default     = "resultados-athena"
}

variable "fecha_inicio_proyeccion" {
  description = "Primera fecha proyectada (incluida), formato yyyy-MM-dd."
  type        = string
  default     = "2026-10-01"
}

variable "fecha_fin_proyeccion" {
  description = "Última fecha proyectada (incluida), formato yyyy-MM-dd."
  type        = string
  default     = "2026-10-03"
}
