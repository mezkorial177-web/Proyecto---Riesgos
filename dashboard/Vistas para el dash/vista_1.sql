CREATE OR REPLACE VIEW riesgos_proyecto.vw_pandemia_vs_postpandemia AS

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