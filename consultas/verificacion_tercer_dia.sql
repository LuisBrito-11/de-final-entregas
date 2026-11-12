-- Verificación de la incorporación del 2026-10-03 sin registrar particiones.
-- Athena ejecuta una sentencia por ejecución: cada consulta se lanza por separado
-- y su resultado se guarda en su propio CSV dentro de resultados/final/.

-- 1) Los seis registros del 2026-10-03 -> resultados/final/verificacion_tercer_dia.csv
SELECT
    fecha,
    id_envio,
    ciudad,
    transportadora,
    estado,
    duracion_minutos
FROM de_gr02_user_4_entregas.entregas
WHERE fecha = '2026-10-03'
ORDER BY id_envio ASC;

-- 2) Conteos por estado del 2026-10-03 -> resultados/final/verificacion_tercer_dia_conteo_por_estado.csv
SELECT
    fecha,
    estado,
    count(*) AS total_intentos
FROM de_gr02_user_4_entregas.entregas
WHERE fecha = '2026-10-03'
GROUP BY fecha, estado
ORDER BY estado ASC;

-- 3) Total de registros de la tabla (tres días) -> resultados/final/verificacion_tercer_dia_total_registros.csv
SELECT
    count(*) AS total_registros
FROM de_gr02_user_4_entregas.entregas;
