-- =============================================================================
-- Poblar dim_fenomeno — fenómenos naturales del catálogo FONDEN/datos.gob.mx
-- =============================================================================

SET search_path TO desastres;

INSERT INTO dim_fenomeno (tipo_fenomeno, categoria, descripcion) VALUES
    ('Lluvias',                     'Hidrometeorológico', 'Precipitaciones intensas que superan umbrales de alerta'),
    ('Inundación',                  'Hidrometeorológico', 'Desbordamiento de cauces y acumulación de agua en zonas habitadas'),
    ('Huracán',                     'Hidrometeorológico', 'Ciclón tropical con vientos sostenidos ≥ 119 km/h'),
    ('Tormenta Severa',             'Hidrometeorológico', 'Combinación de lluvias, granizo, vientos y relámpagos intensos'),
    ('Tromba',                      'Hidrometeorológico', 'Tornado o vórtice sobre cuerpos de agua y/o tierra'),
    ('Tornado',                     'Hidrometeorológico', 'Columna de aire en rotación en contacto con el suelo'),
    ('Granizo',                     'Hidrometeorológico', 'Precipitación sólida de hielo de gran tamaño'),
    ('Helada',                      'Hidrometeorológico', 'Descenso de temperatura por debajo de 0 °C'),
    ('Nevadas',                     'Hidrometeorológico', 'Precipitación de nieve en zonas habitadas'),
    ('Sequía',                      'Hidrometeorológico', 'Déficit prolongado de precipitación respecto a la media histórica'),
    ('Ola de Calor',                'Hidrometeorológico', 'Temperatura excepcionalmente alta por período prolongado'),
    ('Incendio Forestal',           'Químico-Tecnológico','Fuego no controlado en ecosistemas forestales'),
    ('Sismo',                       'Geológico',          'Movimiento sísmico con magnitud registrada'),
    ('Deslizamiento',               'Geológico',          'Movimiento de masa de suelo o roca ladera abajo'),
    ('Derrumbe',                    'Geológico',          'Caída súbita de material rocoso o suelo'),
    ('Erupción Volcánica',          'Geológico',          'Emisión de material volcánico por cráter o fisura'),
    ('Tsunami',                     'Geológico',          'Ola marina generada por sismo o deslizamiento submarino'),
    ('Viento',                      'Hidrometeorológico', 'Vientos fuertes o racheados que superan umbrales de alerta'),
    ('Frente Frío',                 'Hidrometeorológico', 'Avance de masa de aire polar con lluvias y descenso térmico'),
    ('Marea de Tormenta',           'Hidrometeorológico', 'Elevación anormal del nivel del mar asociada a ciclón'),
    ('Desprendimiento de Material', 'Geológico',          'Separación y caída de fragmentos de suelo o roca');

-- Verificación:
-- SELECT tipo_fenomeno, categoria FROM dim_fenomeno ORDER BY categoria, tipo_fenomeno;
