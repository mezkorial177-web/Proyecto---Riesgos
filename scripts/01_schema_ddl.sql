-- =============================================================================
-- Proyecto Final — Análisis de Desastres Naturales en México (2020–2025)
-- =============================================================================
-- Schema:  desastres
-- Grano:   Una fila por declaratoria (emergencia o desastre) registrada
--          en una entidad federativa, para un fenómeno natural específico
--          y un año determinado.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS desastres;
SET search_path TO desastres;

-- -----------------------------------------------------------------------------
-- DIMENSIONES
-- -----------------------------------------------------------------------------

CREATE TABLE dim_estado (
    id_estado       INT             GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clave_estado    VARCHAR(5)      NOT NULL UNIQUE,   -- clave INEGI (01–32)
    estado          VARCHAR(60)     NOT NULL,
    region          VARCHAR(30),                       -- Norte, Centro, Sur-Sureste
    latitud         NUMERIC(9,6),
    longitud        NUMERIC(9,6)
);

CREATE TABLE dim_tiempo (
    id_tiempo       INT             PRIMARY KEY,       -- smart key: YYYY
    anio            SMALLINT        NOT NULL UNIQUE,
    periodo         VARCHAR(20)     NOT NULL,          -- Pre-pandemia / Pandemia / Post-pandemia
    es_postpandemia BOOLEAN         NOT NULL DEFAULT FALSE
);

CREATE TABLE dim_fenomeno (
    id_fenomeno     INT             GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_fenomeno   VARCHAR(80)     NOT NULL UNIQUE,   -- Huracán, Inundación, Sequía, etc.
    categoria       VARCHAR(40),                       -- Hidrometeorológico, Geológico, etc.
    descripcion     TEXT
);

CREATE TABLE dim_tipo_evento (
    id_tipo_evento  SMALLINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_evento     VARCHAR(30)     NOT NULL UNIQUE    -- Emergencia / Desastre / Preventivo
);

-- -----------------------------------------------------------------------------
-- FACT
-- -----------------------------------------------------------------------------

CREATE TABLE fact_eventos_desastres (
    id_evento               BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estado               INT         NOT NULL REFERENCES dim_estado(id_estado),
    id_tiempo               INT         NOT NULL REFERENCES dim_tiempo(id_tiempo),
    id_fenomeno             INT         NOT NULL REFERENCES dim_fenomeno(id_fenomeno),
    id_tipo_evento          SMALLINT    NOT NULL REFERENCES dim_tipo_evento(id_tipo_evento),

    -- Métricas de afectación
    municipios_afectados    INT,
    poblacion_afectada      BIGINT,
    poblacion_atendida      BIGINT,
    costo_total             NUMERIC(18,2),  -- en pesos MXN
    cantidad_eventos        INT             NOT NULL DEFAULT 1
);

-- Índices para queries analíticas
CREATE INDEX idx_fact_estado_tiempo    ON fact_eventos_desastres(id_estado, id_tiempo);
CREATE INDEX idx_fact_fenomeno         ON fact_eventos_desastres(id_fenomeno);
CREATE INDEX idx_fact_tipo_tiempo      ON fact_eventos_desastres(id_tipo_evento, id_tiempo);
CREATE INDEX idx_fact_tiempo           ON fact_eventos_desastres(id_tiempo);

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
-- Listar tablas creadas:
--   SELECT table_name FROM information_schema.tables WHERE table_schema = 'desastres';
--   Esperado: dim_estado, dim_tiempo, dim_fenomeno, dim_tipo_evento, fact_eventos_desastres
