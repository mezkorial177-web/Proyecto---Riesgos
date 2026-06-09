-- =============================================================================
-- Poblar dim_estado — 32 entidades federativas de México con clave INEGI
-- =============================================================================

SET search_path TO desastres;

INSERT INTO dim_estado (clave_estado, estado, region, latitud, longitud) VALUES
    ('01', 'Aguascalientes',      'Centro',        21.8818,  -102.2916),
    ('02', 'Baja California',     'Norte',         30.8406,  -115.2838),
    ('03', 'Baja California Sur', 'Norte',         26.0444,  -111.6661),
    ('04', 'Campeche',            'Sur-Sureste',   19.8301,  -90.5349),
    ('05', 'Coahuila',            'Norte',         27.2938,  -102.0696),
    ('06', 'Colima',              'Centro',        19.2452,  -103.7241),
    ('07', 'Chiapas',             'Sur-Sureste',   16.7569,  -93.1292),
    ('08', 'Chihuahua',           'Norte',         28.6353,  -106.0889),
    ('09', 'Ciudad de México',    'Centro',        19.4326,  -99.1332),
    ('10', 'Durango',             'Norte',         24.0277,  -104.6532),
    ('11', 'Guanajuato',          'Centro',        21.0190,  -101.2574),
    ('12', 'Guerrero',            'Sur-Sureste',   17.4392,  -99.5451),
    ('13', 'Hidalgo',             'Centro',        20.0911,  -98.7624),
    ('14', 'Jalisco',             'Centro',        20.6595,  -103.3494),
    ('15', 'Estado de México',    'Centro',        19.3594,  -99.8475),
    ('16', 'Michoacán',           'Centro',        19.7010,  -101.1844),
    ('17', 'Morelos',             'Centro',        18.9242,  -99.2216),
    ('18', 'Nayarit',             'Norte',         21.7514,  -104.8455),
    ('19', 'Nuevo León',          'Norte',         25.5922,  -99.9962),
    ('20', 'Oaxaca',              'Sur-Sureste',   17.0732,  -96.7266),
    ('21', 'Puebla',              'Centro',        19.0414,  -98.2063),
    ('22', 'Querétaro',           'Centro',        20.5888,  -100.3899),
    ('23', 'Quintana Roo',        'Sur-Sureste',   19.1817,  -88.4791),
    ('24', 'San Luis Potosí',     'Centro',        22.1565,  -100.9855),
    ('25', 'Sinaloa',             'Norte',         25.8167,  -108.2186),
    ('26', 'Sonora',              'Norte',         29.2972,  -110.3309),
    ('27', 'Tabasco',             'Sur-Sureste',   17.9893,  -92.9475),
    ('28', 'Tamaulipas',          'Norte',         24.2669,  -98.8363),
    ('29', 'Tlaxcala',            'Centro',        19.3182,  -98.2374),
    ('30', 'Veracruz',            'Sur-Sureste',   19.1738,  -96.1342),
    ('31', 'Yucatán',             'Sur-Sureste',   20.7099,  -89.0943),
    ('32', 'Zacatecas',           'Norte',         22.7709,  -102.5832);

-- Verificación:
-- SELECT COUNT(*) FROM dim_estado;  -- Esperado: 32
