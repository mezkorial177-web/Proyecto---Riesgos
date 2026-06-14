CREATE OR REPLACE VIEW riesgos_proyecto.vw_ranking_estados_eventos as
WITH por_estado AS (
    SELECT
        de.estado,
        SUM(f.cantidad_eventos)                              AS total_eventos,
        SUM(CASE WHEN dt.anio < 2020
                 THEN f.cantidad_eventos ELSE 0 END)        AS eventos_pre_pandemia,
        SUM(CASE WHEN dt.anio IN (2020, 2021)
                 THEN f.cantidad_eventos ELSE 0 END)        AS eventos_pandemia,
        SUM(CASE WHEN dt.anio >= 2022
                 THEN f.cantidad_eventos ELSE 0 END)        AS eventos_postpandemia,
        SUM(f.municipios_afectados)                         AS total_municipios,
        ROUND(SUM(f.poblacion_afectada))                    AS total_poblacion,
        ROUND(SUM(f.costo_total) / 1e6, 2)                 AS costo_millones_mxn
    FROM      riesgos_proyecto.fact_eventos_desastres  f
    JOIN      riesgos_proyecto.dim_estado   de ON f.id_estado  = de.id_estado
    JOIN      riesgos_proyecto.dim_tiempo   dt ON f.id_tiempo  = dt.id_tiempo
    GROUP BY  de.estado
)
SELECT
    -- Ranking general
    RANK()       OVER (ORDER BY total_eventos DESC)         AS ranking_total,
    -- DENSE_RANK no deja huecos en caso de empate
    DENSE_RANK() OVER (ORDER BY eventos_postpandemia DESC)  AS ranking_postpandemia,
    DENSE_RANK() OVER (ORDER BY eventos_pandemia DESC)      AS ranking_pandemia,

    estado,
    total_eventos,
    eventos_pre_pandemia,
    eventos_pandemia,
    eventos_postpandemia,
    total_municipios,
    total_poblacion,
    costo_millones_mxn,

    -- ¿Empeoró el ranking post pandemia?
    DENSE_RANK() OVER (ORDER BY eventos_pandemia DESC)
    - DENSE_RANK() OVER (ORDER BY eventos_postpandemia DESC) AS cambio_ranking
    -- Positivo = subió en el ranking de riesgo (más eventos post-pandemia relativamente)
    -- Negativo = bajó en el ranking (menos eventos post-pandemia relativamente)

FROM  por_estado
ORDER BY ranking_total;