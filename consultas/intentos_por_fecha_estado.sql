-- Cantidad de intentos por fecha y estado.
-- Sin filtro de fechas: la misma consulta sirve para la etapa inicial (días 1 y 2)
-- y para la final (tres días). fecha sale de la proyección de particiones.
SELECT
    fecha,
    estado,
    count(*) AS total_intentos
FROM de_gr02_user_4_entregas.entregas
GROUP BY fecha, estado
ORDER BY fecha ASC, estado ASC;
