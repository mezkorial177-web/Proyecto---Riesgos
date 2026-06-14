CREATE OR REPLACE VIEW riesgos_proyecto.vw_incremento_postpandemia_fenomenos as
WITH base AS (
    SELECT
        de.estado,
        df.tipo_fenomeno,
        SUM(CASE WHEN dt.anio IN (2020, 2021)
                 THEN f.cantidad_eventos ELSE 0 END)        AS eventos_pandemia,
        SUM(CASE WHEN dt.anio >= 2022
                 THEN f.cantidad_eventos ELSE 0 END)        AS eventos_postpandemia,
        SUM(f.cantidad_eventos)                             AS total_eventos
    FROM      riesgos_proyecto.fact_eventos_desastres  f
    JOIN      riesgos_proyecto.dim_estado    de ON f.id_estado   = de.id_estado
    JOIN      riesgos_proyecto.dim_tiempo    dt ON f.id_tiempo   = dt.id_tiempo
    JOIN      riesgos_proyecto.dim_fenomeno  df ON f.id_fenomeno = df.id_fenomeno
    GROUP BY  de.estado, df.tipo_fenomeno
    HAVING    SUM(f.cantidad_eventos) >= 3   -- filtra combinaciones con muy pocos eventos
),
incrementos AS (
    SELECT
        estado,
        tipo_fenomeno,
        eventos_pandemia,
        eventos_postpandemia,
        total_eventos,

        -- Incremento absoluto
        eventos_postpandemia - eventos_pandemia             AS incremento_absoluto,

        -- Incremento porcentual
        -- NULLIF evita división por cero cuando no hubo eventos durante pandemia
        ROUND(
            100.0 * (eventos_postpandemia - eventos_pandemia)
                  / NULLIF(eventos_pandemia, 0),
            1
        )                                                   AS incremento_pct,

        -- Clasificación de severidad del cambio
        CASE
            WHEN eventos_pandemia = 0
             AND eventos_postpandemia > 0       THEN 'NUEVO POST-PANDEMIA'
            WHEN ROUND(
                    100.0 * (eventos_postpandemia - eventos_pandemia)
                          / NULLIF(eventos_pandemia, 0), 1
                 ) > 50                         THEN 'INCREMENTO ALTO (>50%)'
            WHEN ROUND(
                    100.0 * (eventos_postpandemia - eventos_pandemia)
                          / NULLIF(eventos_pandemia, 0), 1
                 ) BETWEEN 10 AND 50            THEN 'INCREMENTO MODERADO'
            WHEN ROUND(
                    100.0 * (eventos_postpandemia - eventos_pandemia)
                          / NULLIF(eventos_pandemia, 0), 1
                 ) < 0                          THEN 'REDUCCIÓN'
            ELSE                                     'ESTABLE'
        END                                             AS clasificacion
    FROM base
)
SELECT *
FROM  incrementos
ORDER BY incremento_absoluto DESC NULLS LAST,
         incremento_pct       DESC NULLS LAST;