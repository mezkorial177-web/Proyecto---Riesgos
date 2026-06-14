CREATE OR REPLACE VIEW riesgos_proyecto.vw_evolucion_anual_eventos as
WITH anual AS (
    SELECT
        dt.anio,
        dte.tipo_evento,
        SUM(f.cantidad_eventos)                              AS total_eventos,
        SUM(f.municipios_afectados)                         AS total_municipios,
        ROUND(SUM(f.poblacion_afectada))                    AS total_poblacion,
        ROUND(SUM(f.costo_total) / 1e6, 2)                 AS costo_millones_mxn
    FROM      riesgos_proyecto.fact_eventos_desastres  f
    JOIN      riesgos_proyecto.dim_tiempo       dt  ON f.id_tiempo      = dt.id_tiempo
    JOIN      riesgos_proyecto.dim_tipo_evento  dte ON f.id_tipo_evento = dte.id_tipo_evento
    GROUP BY  dt.anio, dte.tipo_evento
)
SELECT
    anio,
    tipo_evento,
    total_eventos,
    total_municipios,
    total_poblacion,
    costo_millones_mxn,

    -- Año anterior (Window Function LAG)
    LAG(total_eventos) OVER (
        PARTITION BY tipo_evento
        ORDER BY     anio
    )                                                       AS eventos_anio_anterior,

    -- Diferencia absoluta respecto al año anterior
    total_eventos - LAG(total_eventos) OVER (
        PARTITION BY tipo_evento
        ORDER BY     anio
    )                                                       AS delta_eventos,

    -- Variación porcentual respecto al año anterior
    ROUND(
        100.0 * total_eventos
              / NULLIF(LAG(total_eventos) OVER (
                    PARTITION BY tipo_evento ORDER BY anio
                ), 0) - 100,
        1
    )                                                       AS variacion_pct,

    -- Etiqueta del período
    CASE
        WHEN anio < 2020  THEN 'Pre-pandemia'
        WHEN anio <= 2021 THEN 'Pandemia'
        ELSE                   'Post-pandemia'
    END                                                     AS periodo

FROM  anual
ORDER BY tipo_evento, anio;