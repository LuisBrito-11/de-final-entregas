-- Compuerta de control (no forma parte de las consultas oficiales).
-- Cuenta los registros consultables y cuántos son del 2026-10-03.
SELECT
    count(*) AS total_registros,
    sum(CASE WHEN fecha = '2026-10-03' THEN 1 ELSE 0 END) AS registros_2026_10_03,
    count(DISTINCT fecha) AS fechas_con_datos
FROM de_gr02_user_4_entregas.entregas;
