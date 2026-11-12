terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  ubicacion_datos      = "s3://${aws_s3_bucket.datos.bucket}/${var.prefijo_datos}/"
  ubicacion_resultados = "s3://${aws_s3_bucket.datos.bucket}/${var.prefijo_resultados_athena}/"
}

# ---------------------------------------------------------------------------
# S3: bucket privado con los datos (entregas/) y los resultados de Athena
# (resultados-athena/). Los prefijos son parte de las claves de los objetos,
# así que no se crean "carpetas".
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "datos" {
  bucket = var.nombre_bucket

  # El bucket se vacía con la CLI antes del destroy (ver README).
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "datos" {
  bucket = aws_s3_bucket.datos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "datos" {
  bucket = aws_s3_bucket.datos.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datos" {
  bucket = aws_s3_bucket.datos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# Glue Data Catalog: base de datos y tabla externa con partition projection.
# ---------------------------------------------------------------------------
resource "aws_glue_catalog_database" "entregas" {
  name        = var.nombre_base_datos
  description = "Intentos de entrega de paquetes (examen final, punto 1)."
}

resource "aws_glue_catalog_table" "entregas" {
  name          = var.nombre_tabla
  database_name = aws_glue_catalog_database.entregas.name
  description   = "Un intento de entrega por fila. La fecha sale de la carpeta fecha=yyyy-MM-dd."
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"               = "TRUE"
    "classification"         = "csv"
    "skip.header.line.count" = "1"

    # Partition projection: Athena calcula las particiones durante la consulta
    # a partir de estas reglas. No se registra ninguna partición en el catálogo.
    "projection.enabled"             = "true"
    "projection.fecha.type"          = "date"
    "projection.fecha.format"        = "yyyy-MM-dd"
    "projection.fecha.range"         = "${var.fecha_inicio_proyeccion},${var.fecha_fin_proyeccion}"
    "projection.fecha.interval"      = "1"
    "projection.fecha.interval.unit" = "DAYS"
    # $${fecha} produce el texto literal ${fecha} (Terraform no lo interpola).
    # La plantilla describe el prefijo de la partición y termina en "/".
    "storage.location.template" = "${local.ubicacion_datos}fecha=$${fecha}/"
  }

  # fecha es clave de partición de tipo texto y no es columna del CSV.
  partition_keys {
    name    = "fecha"
    type    = "string"
    comment = "Fecha del archivo diario, tomada de la carpeta fecha=yyyy-MM-dd."
  }

  storage_descriptor {
    location      = local.ubicacion_datos
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "csv-coma"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"

      parameters = {
        "field.delim"          = ","
        "serialization.format" = ","
      }
    }

    # Cinco columnas en el orden del diccionario de datos.
    columns {
      name    = "id_envio"
      type    = "string"
      comment = "Identificador único del envío."
    }

    columns {
      name    = "ciudad"
      type    = "string"
      comment = "Ciudad del intento de entrega."
    }

    columns {
      name    = "transportadora"
      type    = "string"
      comment = "Transportadora responsable del intento."
    }

    columns {
      name    = "estado"
      type    = "string"
      comment = "entregado, destinatario_ausente o direccion_incorrecta."
    }

    columns {
      name    = "duracion_minutos"
      type    = "int"
      comment = "Duración en minutos; 0 en los intentos fallidos."
    }
  }
}

# ---------------------------------------------------------------------------
# Athena: workgroup con la ubicación de resultados forzada en resultados-athena/.
# ---------------------------------------------------------------------------
resource "aws_athena_workgroup" "entregas" {
  name          = var.nombre_workgroup
  description   = "Consultas del examen final sobre la tabla de entregas."
  state         = "ENABLED"
  force_destroy = true # permite eliminarlo aunque tenga historial de consultas

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = local.ubicacion_resultados

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
