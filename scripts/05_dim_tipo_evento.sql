-- =============================================================================
-- Poblar dim_tipo_evento — tipos de declaratoria
-- =============================================================================

SET search_path TO desastres;

INSERT INTO dim_tipo_evento (tipo_evento) VALUES
    ('Emergencia'),    -- Declaratoria de Emergencia (respuesta inmediata)
    ('Desastre'),      -- Declaratoria de Desastre (daños ya ocurridos)
    ('Preventivo');    -- Proyecto Preventivo (acción antes del evento)

-- Verificación:
-- SELECT * FROM dim_tipo_evento;
