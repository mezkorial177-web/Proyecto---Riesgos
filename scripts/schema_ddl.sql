CREATE SCHEMA IF NOT EXISTS riesgos_proyecto;
------ Creación del modelo dimensional
------ TABLAS ES DATOS CRUDOS 

CREATE TABLE riesgos_proyecto.stg_declaratorias_desastre (
    no INTEGER,
    entidad_federativa TEXT,
    anio INTEGER,
    evento TEXT,
    tipo_fenomeno TEXT,
    instancia_corroboradora TEXT,
    documento_corroboracion TEXT,
    nombre_municipios_corroborados TEXT,
    numero_municipios_corroborados INTEGER,
    instalacion_ced TEXT,
    sectores_afectados TEXT,
    fecha_publicacion_dof TEXT,
    publicacion_dof TEXT,
    entrega_resultados_ced TEXT,
    limite_para_entregar_diagnostico TEXT,
    oficio_entrega TEXT,
    observaciones TEXT,
    ultima_fecha_actualizacion TEXT
);


CREATE TABLE riesgos_proyecto.stg_proyectos_prevencion (
    consecutivo TEXT,
    entidad_federativa_solicitante TEXT,
    instancia_publica_orden_federal_solicitante TEXT,
    nombre_proyecto TEXT,
    anio_autorizacion TEXT,
    instancia_ejecutora TEXT,
    tipo_proyecto TEXT,
    tipo_fenomeno_01 TEXT,
    tipo_fenomeno_2 TEXT,
    tipo_fenomeno_3 TEXT,
    estatus TEXT,
    personas_beneficiadas TEXT,
    mujeres TEXT,
    hombres TEXT,
    poblacion_indigena TEXT,
    anio_finalizacion TEXT,
    proyecto_estrategico TEXT,
    recurso_fondo_preventivo_federal TEXT,
    recurso_coparticipacion_estatal TEXT,
    costo_total_mxn_peso TEXT,
    pagina_web_instancia_autorizada TEXT,
    ultima_fecha_actualizacion TEXT
);



CREATE TABLE riesgos_proyecto.stg_declaratorias_emergencia (
    no TEXT,
    entidad_federativa TEXT,
    anio_ocurrencia_evento TEXT,
    boletin_prensa TEXT,
    fecha_emision_boletin_prensa TEXT,
    tipo_fenomeno TEXT,
    amenaza_natural TEXT,
    instancia_corroboradora TEXT,
    nombre_municipios_corroborados TEXT,
    numero_municipios_corroborados TEXT,
    oficio_poblacion_afectada TEXT,
    poblacion_afectada TEXT,
    poblacion_atendida TEXT,
    fecha_publicacion_declaratoria_dof TEXT,
    publicacion_dof TEXT,
    instancia_que_elaboro_informe_utilizacion_insumos TEXT,
    boletin_prensa_aviso_termino_emergencia TEXT,
    fecha_emision_boletin_prensa_termino_situacion_emergencia TEXT,
    fecha_publicacion_aviso_termino_declaratoria_dof TEXT,
    publicacion_termino_dof TEXT,
    total_insumos_autorizados TEXT,
    despensas TEXT,
    despensa_sobrevivencia TEXT,
    despensa_mantenimiento TEXT,
    alimentos_consumo_inmediato TEXT,
    fruta_para_poblacion TEXT,
    alimento_granel TEXT,
    cobertor_a TEXT,
    cobertor_b TEXT,
    colchoneta TEXT,
    hamaca TEXT,
    lamina_tipo_a TEXT,
    lamina_tipo_b TEXT,
    lamina_tipo_c TEXT,
    palma_sintetica TEXT,
    palma_natural TEXT,
    litros_agua TEXT,
    kit_limpieza TEXT,
    kit_aseo_personal TEXT,
    costales TEXT,
    saco_absorbente TEXT,
    impermeables TEXT,
    botas TEXT,
    rollos_hule TEXT,
    guantes_carnaza TEXT,
    toallas_sanitarias_femeninas TEXT,
    banieras_para_bebe TEXT,
    panial_etapa_5 TEXT,
    panial_etapa_4 TEXT,
    panial_etapa_3 TEXT,
    panial_etapa_2 TEXT,
    panial_etapa_1 TEXT,
    panial_para_adulto TEXT,
    linternas TEXT,
    palas TEXT,
    marros TEXT,
    barretas TEXT,
    machetes TEXT,
    martillos TEXT,
    carretillas TEXT,
    cascos TEXT,
    azadones TEXT,
    hachas TEXT,
    zapapicos TEXT,
    motosierras TEXT,
    mochilas_aspersores TEXT,
    mascarillas TEXT,
    cocinas_comunitarias TEXT,
    servicios_potabilizadoras_agua TEXT,
    servicio_bombas_extraccion_agua TEXT,
    servicio_retroexcavadoras TEXT,
    servicio_vactors TEXT,
    envases_agua TEXT,
    combustible TEXT,
    fletes TEXT,
    servicio_letrinas TEXT,
    servicio_regaderas TEXT,
    arrendamiento_montacargas TEXT,
    arrendamiento_generadores_energia TEXT,
    lote_insumos_para_salud TEXT,
    costo_fuerzas_armadas TEXT,
    costo_estimado_sspc TEXT,
    costo_total_declaratoria TEXT,
    observaciones TEXT
);

--- VERIFICACION 
SELECT COUNT(*) 
FROM riesgos_proyecto.stg_declaratorias_desastre;

SELECT COUNT(*) 
FROM riesgos_proyecto.stg_declaratorias_emergencia;

SELECT COUNT(*) 
FROM riesgos_proyecto.stg_proyectos_prevencion;


-------------------- DIMENSIONES 

-- Dimension Estado
CREATE TABLE riesgos_proyecto.dim_estado (
    id_estado SERIAL PRIMARY KEY,
    estado VARCHAR(100) NOT NULL UNIQUE
);

-- Dimensión Tiempo
CREATE TABLE riesgos_proyecto.dim_tiempo (
    id_tiempo SERIAL PRIMARY KEY,
    anio INTEGER NOT NULL UNIQUE
);

--Dimensión Fenómeno
CREATE TABLE riesgos_proyecto.dim_fenomeno (
    id_fenomeno SERIAL PRIMARY KEY,
    tipo_fenomeno VARCHAR(200) NOT NULL UNIQUE
);

--Dimensión Tipo Evento
CREATE TABLE riesgos_proyecto.dim_tipo_evento (
    id_tipo_evento SERIAL PRIMARY KEY,
    tipo_evento VARCHAR(50) NOT NULL UNIQUE
);

-- FACT
----La tabla principal de hechos sería fact_eventos_desastres
CREATE TABLE riesgos_proyecto.fact_eventos_desastres (
    id_evento INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estado INTEGER NOT NULL,
    id_tiempo INTEGER NOT NULL,
    id_fenomeno INTEGER NOT NULL,
    id_tipo_evento INTEGER NOT NULL,
    municipios_afectados INTEGER,  
    poblacion_afectada NUMERIC(18,2),
    poblacion_atendida NUMERIC(18,2),
    costo_total NUMERIC(18,2),
    cantidad_eventos INTEGER DEFAULT 1,
    CONSTRAINT fk_fact_estado
        FOREIGN KEY (id_estado)
        REFERENCES riesgos_proyecto.dim_estado(id_estado),
    CONSTRAINT fk_fact_tiempo
        FOREIGN KEY (id_tiempo)
        REFERENCES riesgos_proyecto.dim_tiempo(id_tiempo),
    CONSTRAINT fk_fact_fenomeno
        FOREIGN KEY (id_fenomeno)
        REFERENCES riesgos_proyecto.dim_fenomeno(id_fenomeno),
    CONSTRAINT fk_fact_tipo_evento
        FOREIGN KEY (id_tipo_evento)
        REFERENCES riesgos_proyecto.dim_tipo_evento(id_tipo_evento)
);



-- VERIFICACIÓN
-- Listar tablas creadas

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'riesgos_proyecto'
ORDER BY table_name;

-- Esperado:
-- dim_estado
-- dim_tiempo
-- dim_fenomeno
-- dim_tipo_evento
-- fact_eventos_desastres
