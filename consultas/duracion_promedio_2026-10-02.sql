-- Duración promedio de las entregas exitosas del 2 de octubre de 2026.
-- Solo estado 'entregado' (los fallidos tienen duración 0 y no deben bajar el
-- promedio). Un único valor para todas las ciudades y transportadoras, con dos
-- decimales. El filtro por fecha (columna de partición) limita la lectura a
-- s3://<bucket>/entregas/fecha=2026-10-02/.
SELECT
    fecha,
    CAST(round(avg(CAST(duracion_minutos AS double)), 2) AS decimal(10, 2)) AS duracion_promedio_minutos
FROM de_gr02_user_4_entregas.entregas
WHERE fecha = '2026-10-02'
  AND estado = 'entregado'
GROUP BY fecha;
