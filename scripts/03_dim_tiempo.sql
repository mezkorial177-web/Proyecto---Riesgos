-- =============================================================================
-- Poblar dim_tiempo — años 2020 a 2025 con clasificación pandemia
-- =============================================================================

SET search_path TO desastres;

INSERT INTO dim_tiempo (id_tiempo, anio, periodo, es_postpandemia) VALUES
    (2020, 2020, 'Pandemia',       FALSE),
    (2021, 2021, 'Pandemia',       FALSE),
    (2022, 2022, 'Post-pandemia',  TRUE),
    (2023, 2023, 'Post-pandemia',  TRUE),
    (2024, 2024, 'Post-pandemia',  TRUE),
    (2025, 2025, 'Post-pandemia',  TRUE);

-- Verificación:
-- SELECT * FROM dim_tiempo ORDER BY anio;
