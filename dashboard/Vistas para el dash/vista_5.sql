CREATE OR REPLACE VIEW riesgos_proyecto.vw_eventos_estados as
WITH por_estado AS (
    SELECT
        de.estado,
        SUM(f.cantidad_eventos)                             AS total_eventos,
        ROUND(SUM(f.poblacion_afectada))                   AS poblacion_afectada
    FROM      riesgos_proyecto.fact_eventos_desastres  f
    JOIN      riesgos_proyecto.dim_estado de ON f.id_estado = de.id_estado
    GROUP BY  de.estado
),
total_nacional AS (
    SELECT SUM(total_eventos) AS gran_total
    FROM   por_estado
)
SELECT
    pe.estado,
    pe.total_eventos,
    pe.poblacion_afectada,

    -- Participación de este estado en el total nacional
    ROUND(100.0 * pe.total_eventos / tn.gran_total, 2)     AS pct_nacional,

    -- Acumulado de eventos (ordenado de mayor a menor)
    SUM(pe.total_eventos) OVER (
        ORDER BY pe.total_eventos DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                       AS eventos_acumulados,

    -- Porcentaje acumulado
    ROUND(
        100.0 * SUM(pe.total_eventos) OVER (
            ORDER BY pe.total_eventos DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / tn.gran_total,
        1
    )                                                       AS pct_acumulado,

    CASE
        WHEN ROUND(
            100.0 * SUM(pe.total_eventos) OVER (
                ORDER BY pe.total_eventos DESC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) / tn.gran_total, 1
        ) <= 80 THEN 'TOP 80% de eventos'
        ELSE         'Resto'
    END                                                     AS grupo_pareto

FROM  por_estado pe, total_nacional tn
ORDER BY pe.total_eventos DESC;