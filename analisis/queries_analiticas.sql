-- =============================================================================
-- SQL Avanzado — Análisis de Desastres Naturales en México
-- Schema: riesgos_proyecto
-- Pregunta analítica: ¿Qué cambios ocurrieron en el perfil de los desastres
-- naturales en México después de la pandemia y qué estados experimentaron
-- el mayor incremento en afectaciones?
--
-- Técnicas utilizadas:
--   Q1 → CTE + agregación condicional (SUM CASE)
--   Q2 → CTE + Window Function LAG()
--   Q3 → CTE + RANK() / DENSE_RANK()
--   Q4 → CTE anidado + incremento porcentual post-pandemia
--   Q5 → Window Function SUM() OVER (acumulado tipo Pareto)
-- =============================================================================

-- =============================================================================
-- QUERY 1: Comparación de eventos ANTES vs DESPUÉS de la pandemia
-- Técnica: CTE + agregación condicional (SUM CASE)
--
-- Pandemia:      2020 – 2021
-- Post-pandemia: 2022 en adelante
--
-- Responde: ¿Cambió el volumen total de declaratorias después de la pandemia?
-- =============================================================================

WITH periodo AS (
    SELECT
        de.estado,
        dte.tipo_evento,
        df.tipo_fenomeno,

        -- Pandemia (2020–2021)
        SUM(CASE WHEN dt.anio IN (2020, 2021)
                 THEN f.cantidad_eventos ELSE 0 END)          AS eventos_pandemia,

        -- Post-pandemia (2022 en adelante)
        SUM(CASE WHEN dt.anio >= 2022
                 THEN f.cantidad_eventos ELSE 0 END)          AS eventos_postpandemia,

        -- Total histórico
        SUM(f.cantidad_eventos)                               AS total_historico,

        -- Métricas de impacto
        SUM(CASE WHEN dt.anio >= 2022
                 THEN f.municipios_afectados ELSE 0 END)      AS municipios_postpandemia,
        SUM(CASE WHEN dt.anio >= 2022
                 THEN f.poblacion_afectada   ELSE 0 END)      AS poblacion_postpandemia

    FROM      riesgos_proyecto.fact_eventos_desastres  f
    JOIN      riesgos_proyecto.dim_estado       de  ON f.id_estado      = de.id_estado
    JOIN      riesgos_proyecto.dim_tiempo       dt  ON f.id_tiempo      = dt.id_tiempo
    JOIN      riesgos_proyecto.dim_fenomeno     df  ON f.id_fenomeno    = df.id_fenomeno
    JOIN      riesgos_proyecto.dim_tipo_evento  dte ON f.id_tipo_evento = dte.id_tipo_evento
    GROUP BY  de.estado, dte.tipo_evento, df.tipo_fenomeno
)
SELECT
    estado,
    tipo_evento,
    tipo_fenomeno,
    eventos_pandemia,
    eventos_postpandemia,
    total_historico,
    municipios_postpandemia,
    ROUND(poblacion_postpandemia)                             AS poblacion_postpandemia,

    -- Diferencia absoluta
    eventos_postpandemia - eventos_pandemia                   AS diferencia_absoluta,

    -- Clasificación del cambio
    CASE
        WHEN eventos_postpandemia > eventos_pandemia THEN 'AUMENTO'
        WHEN eventos_postpandemia < eventos_pandemia THEN 'DISMINUCIÓN'
        ELSE 'SIN CAMBIO'
    END                                                       AS tendencia

FROM  periodo
WHERE total_historico > 0
ORDER BY diferencia_absoluta DESC, estado;


-- =============================================================================
-- QUERY 2: Evolución anual con crecimiento año a año
-- Técnica: CTE + Window Function LAG()
--
-- Responde: ¿En qué años hubo los mayores picos de actividad?
-- =============================================================================

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


-- =============================================================================
-- QUERY 3: Ranking de estados por total de eventos (pre vs post pandemia)
-- Técnica: CTE + RANK() y DENSE_RANK()
--
-- Responde: ¿Qué estados concentran más declaratorias históricamente?
--           ¿Cambió el ranking entre períodos?
-- =============================================================================

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


-- =============================================================================
-- QUERY 4: Incremento porcentual post-pandemia por estado y fenómeno
-- Técnica: CTE anidado + cálculo de incremento porcentual
--
-- Responde: ¿Qué estados y fenómenos tuvieron el mayor incremento porcentual
--           de eventos después de la pandemia?
-- =============================================================================

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


-- =============================================================================
-- QUERY 5: Concentración de eventos por estado — análisis Pareto
-- Técnica: Window Function SUM() OVER (acumulado)
--
-- Responde: ¿Cuántos estados concentran el 80% de todos los eventos?
--           (Regla 80/20 aplicada a desastres)
-- =============================================================================

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

    -- Etiqueta Pareto
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
