-- Porcentaje de entregas exitosas por fecha y ciudad:
-- 100 * entregas con estado 'entregado' / total de intentos (todos los estados).
-- Se convierte a double antes de dividir para evitar la división entera y se
-- presenta como decimal(5,2) para conservar siempre dos decimales.
-- Sin filtro de fechas: sirve igual para la etapa inicial y la final.
SELECT
    fecha,
    ciudad,
    CAST(
        round(
            100 * CAST(sum(CASE WHEN estado = 'entregado' THEN 1 ELSE 0 END) AS double)
                / CAST(count(*) AS double),
            2
        ) AS decimal(5, 2)
    ) AS porcentaje_exito
FROM de_gr02_user_4_entregas.entregas
GROUP BY fecha, ciudad
ORDER BY fecha ASC, ciudad ASC;
