-- =============================================================================
-- Queries analíticas con SQL avanzado — Desastres Naturales México 2020–2025
-- =============================================================================
-- Cinco queries que cubren las técnicas del módulo:
--   1. CTE + ranking de estados por incremento de declaratorias
--   2. Window Function LAG() para crecimiento anual
--   3. Comparación pre vs. post pandemia por fenómeno
--   4. Ranking acumulado de fenómenos más frecuentes (DENSE_RANK)
--   5. CTE anidado + porcentaje de participación estatal
-- =============================================================================

SET search_path TO desastres;


-- -----------------------------------------------------------------------------
-- 1. Top 10 estados con mayor incremento de declaratorias post-pandemia
--    Técnica: CTE + agregación condicional (SUM CASE) + ORDER BY calculado
-- -----------------------------------------------------------------------------

WITH declaratorias_periodo AS (
    SELECT
        de.estado,
        de.region,
        SUM(CASE WHEN dt.es_postpandemia = FALSE THEN f.cantidad_eventos ELSE 0 END)  AS eventos_pandemia,
        SUM(CASE WHEN dt.es_postpandemia = TRUE  THEN f.cantidad_eventos ELSE 0 END)  AS eventos_postpandemia
    FROM      fact_eventos_desastres f
    JOIN      dim_estado   de  USING (id_estado)
    JOIN      dim_tiempo   dt  USING (id_tiempo)
    GROUP BY  de.estado, de.region
)
SELECT
    estado,
    region,
    eventos_pandemia,
    eventos_postpandemia,
    eventos_postpandemia - eventos_pandemia                                           AS incremento_absoluto,
    CASE
        WHEN eventos_pandemia = 0 THEN NULL
        ELSE ROUND(
            100.0 * (eventos_postpandemia - eventos_pandemia) / eventos_pandemia, 1
        )
    END                                                                               AS incremento_pct
FROM  declaratorias_periodo
ORDER BY incremento_absoluto DESC NULLS LAST
LIMIT 10;


-- -----------------------------------------------------------------------------
-- 2. Evolución anual de declaratorias con crecimiento año a año (LAG)
--    Técnica: CTE + Window Function LAG() particionada por tipo de evento
-- -----------------------------------------------------------------------------

WITH anual AS (
    SELECT
        dte.tipo_evento,
        dt.anio,
        SUM(f.cantidad_eventos)       AS total_declaratorias,
        SUM(f.municipios_afectados)   AS total_municipios,
        SUM(f.poblacion_afectada)     AS total_poblacion
    FROM      fact_eventos_desastres f
    JOIN      dim_tipo_evento  dte USING (id_tipo_evento)
    JOIN      dim_tiempo       dt  USING (id_tiempo)
    GROUP BY  dte.tipo_evento, dt.anio
)
SELECT
    tipo_evento,
    anio,
    total_declaratorias,
    total_municipios,
    total_poblacion,
    LAG(total_declaratorias) OVER (
        PARTITION BY tipo_evento
        ORDER BY     anio
    )                                                                         AS declaratorias_anio_anterior,
    total_declaratorias - LAG(total_declaratorias) OVER (
        PARTITION BY tipo_evento
        ORDER BY     anio
    )                                                                         AS delta_absoluto,
    ROUND(
        100.0 * total_declaratorias
              / NULLIF(LAG(total_declaratorias) OVER (
                    PARTITION BY tipo_evento ORDER BY anio
                ), 0) - 100,
        1
    )                                                                         AS variacion_pct
FROM  anual
ORDER BY tipo_evento, anio;


-- -----------------------------------------------------------------------------
-- 3. Comparación de fenómenos pre vs. post pandemia
--    Técnica: PIVOT con SUM CASE + filtro de fenómenos con al menos 10 eventos
-- -----------------------------------------------------------------------------

WITH por_fenomeno AS (
    SELECT
        df.tipo_fenomeno,
        df.categoria,
        SUM(CASE WHEN dt.anio IN (2020, 2021) THEN f.cantidad_eventos ELSE 0 END) AS eventos_2020_2021,
        SUM(CASE WHEN dt.anio IN (2022, 2023, 2024, 2025) THEN f.cantidad_eventos ELSE 0 END) AS eventos_2022_2025,
        SUM(f.cantidad_eventos)                                                    AS total
    FROM      fact_eventos_desastres f
    JOIN      dim_fenomeno df USING (id_fenomeno)
    JOIN      dim_tiempo   dt USING (id_tiempo)
    GROUP BY  df.tipo_fenomeno, df.categoria
    HAVING    SUM(f.cantidad_eventos) >= 10
)
SELECT
    tipo_fenomeno,
    categoria,
    eventos_2020_2021,
    eventos_2022_2025,
    total,
    ROUND(
        100.0 * (eventos_2022_2025 - eventos_2020_2021) / NULLIF(eventos_2020_2021, 0),
        1
    )                                                                              AS cambio_pct
FROM  por_fenomeno
ORDER BY cambio_pct DESC NULLS LAST;


-- -----------------------------------------------------------------------------
-- 4. Ranking de fenómenos más frecuentes por región (DENSE_RANK)
--    Técnica: CTE + Window Function DENSE_RANK() particionado por región
-- -----------------------------------------------------------------------------

WITH conteo AS (
    SELECT
        de.region,
        df.tipo_fenomeno,
        df.categoria,
        SUM(f.cantidad_eventos)     AS total_eventos,
        SUM(f.municipios_afectados) AS municipios_afectados,
        SUM(f.poblacion_afectada)   AS poblacion_afectada
    FROM      fact_eventos_desastres f
    JOIN      dim_estado   de USING (id_estado)
    JOIN      dim_fenomeno df USING (id_fenomeno)
    GROUP BY  de.region, df.tipo_fenomeno, df.categoria
)
SELECT
    region,
    tipo_fenomeno,
    categoria,
    total_eventos,
    municipios_afectados,
    poblacion_afectada,
    DENSE_RANK() OVER (
        PARTITION BY region
        ORDER BY     total_eventos DESC
    )                           AS ranking_en_region
FROM  conteo
WHERE ranking_en_region <= 5    -- top 5 por región
ORDER BY region, ranking_en_region;


-- -----------------------------------------------------------------------------
-- 5. Participación de cada estado en el total nacional + acumulado (SUM OVER)
--    Técnica: CTE + SUM() como window function para total acumulado
-- -----------------------------------------------------------------------------

WITH estatal AS (
    SELECT
        de.estado,
        de.region,
        SUM(f.cantidad_eventos)                             AS total_eventos,
        SUM(f.municipios_afectados)                        AS total_municipios,
        ROUND(SUM(f.costo_total) / 1e6, 2)                 AS costo_millones_mxn
    FROM      fact_eventos_desastres f
    JOIN      dim_estado de USING (id_estado)
    GROUP BY  de.estado, de.region
),
nacional AS (
    SELECT SUM(total_eventos) AS gran_total FROM estatal
)
SELECT
    e.estado,
    e.region,
    e.total_eventos,
    e.total_municipios,
    e.costo_millones_mxn,
    ROUND(100.0 * e.total_eventos / n.gran_total, 2)       AS pct_nacional,
    SUM(e.total_eventos) OVER (
        ORDER BY e.total_eventos DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                       AS acumulado,
    ROUND(
        100.0 * SUM(e.total_eventos) OVER (
            ORDER BY e.total_eventos DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / n.gran_total,
        1
    )                                                       AS pct_acumulado
FROM  estatal e, nacional n
ORDER BY e.total_eventos DESC;
