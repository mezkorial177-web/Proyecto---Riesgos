# Proyecto Final — Análisis de la Evolución de los Desastres Naturales en México (2020–2025)

> ℹ️ Este proyecto analiza cómo cambió el perfil de los desastres naturales en México después de la pandemia, utilizando los datos abiertos de Gestión de Riesgos del Gobierno de México. El README sigue la estructura de la rúbrica del módulo: problema, datos, modelo, ETL, SQL avanzado y dashboard.

## 📋 Resumen ejecutivo

| Campo                | Valor |
|----------------------|-------|
| **Pregunta analítica** | ¿Qué cambios ocurrieron en el perfil de los desastres naturales en México después de la pandemia y qué estados experimentaron el mayor incremento en afectaciones? |
| **Dataset**          | Declaratorias de Emergencia, Declaratorias de Desastre y Proyectos Preventivos — Gestión de Riesgos |
| **Fuente**           | [datos.gob.mx — Gestión de Riesgos](https://datos.gob.mx/busca/dataset/gestion-de-riesgos) |
| **Modelo**           | Esquema estrella con 1 tabla de hechos y 4 dimensiones |
| **Infraestructura**  | Aurora PostgreSQL en AWS (schema `desastres`) |
| **ETL**              | `etl_pipeline.py` con pandas + SQLAlchemy + validaciones post-carga |
| **SQL avanzado**     | CTEs, Window Functions (LAG, DENSE_RANK, SUM OVER), agregación condicional (SUM CASE), ranking |
| **Dashboard**        | 4 visualizaciones estáticas (matplotlib): evolución anual, top estados, fenómenos frecuentes, mapa |

---

## 🎯 Problema y motivación

México es uno de los países con mayor exposición a fenómenos naturales extremos: huracanes en ambos litorales, inundaciones en el sureste, sequías en el norte y sismos en el centro y sur. El **FONDEN (Fondo Nacional de Desastres)** y el **CENAPRED** documentan estas afectaciones a través de declaratorias oficiales de emergencia y desastre.

Después de la pandemia por COVID-19 (2020–2021), diversos factores pudieron haber modificado los patrones históricos de afectación:

- Deterioro de infraestructura de drenaje y prevención por falta de mantenimiento.
- Efectos acumulados del cambio climático (mayor intensidad de huracanes, sequías extendidas).
- Cambios en la capacidad institucional de respuesta por presupuestos ajustados.
- Mayor urbanización en zonas de riesgo durante el período.

Comprender estos cambios permite:

- Identificar estados con mayor incremento en afectaciones para priorizar recursos.
- Detectar fenómenos emergentes o con tendencia creciente.
- Apoyar la toma de decisiones en materia de protección civil.
- Informar políticas de prevención y mitigación basadas en evidencia.

**Este proyecto responde tres preguntas concretas:**

1. ¿Cómo evolucionó el número de declaratorias de emergencia y desastre entre 2020 y 2025?
2. ¿Qué fenómenos naturales aumentaron su frecuencia después de la pandemia?
3. ¿Qué estados registraron el mayor incremento en afectaciones post-pandemia?

---

## 📦 Origen de los datos

Los datos provienen del portal público **Datos Abiertos del Gobierno de México** ([datos.gob.mx](https://datos.gob.mx)), específicamente del dataset de **Gestión de Riesgos** administrado por la Coordinación Nacional de Protección Civil (CNPC).

### Tablas fuente utilizadas

| Dataset | Descripción | Tipo de evento |
|---------|-------------|----------------|
| Declaratorias de Emergencia | Declaratorias emitidas ante fenómenos inminentes que requieren respuesta inmediata | Emergencia |
| Declaratorias de Desastre | Declaratorias emitidas una vez ocurridos los daños, para activar recursos FONDEN | Desastre |
| Proyectos Preventivos | Proyectos aprobados para mitigación antes del evento | Preventivo |

Los archivos se descargan en formato CSV y se cargan a Aurora PostgreSQL mediante el ETL desarrollado en Python.

### Flujo end-to-end

```
┌─────────────────────────────────────────┐
│  Datos Abiertos Gobierno de México      │
│  datos.gob.mx — Gestión de Riesgos     │
│                                         │
│  • Declaratorias de Emergencia (CSV)    │
│  • Declaratorias de Desastre (CSV)      │
│  • Proyectos Preventivos (CSV)          │
└─────────────────────┬───────────────────┘
                      │  Descarga CSV / API CKAN
                      ▼
┌─────────────────────────────────────────┐
│  ETL Python — etl_pipeline.py           │
│                                         │
│  Extract:   requests.get / read_csv     │
│  Transform: pandas (normalización,      │
│             filtro 2020–2025,           │
│             resolución de claves)       │
│  Load:      to_sql(method='multi')      │
└─────────────────────┬───────────────────┘
                      │  INSERT
                      ▼
┌─────────────────────────────────────────┐
│  Aurora PostgreSQL                      │
│  Schema: desastres                      │
│                                         │
│  • 4 dims pobladas con SQL puro         │
│    (scripts/02–05_*.sql)                │
│  • fact_eventos_desastres cargada       │
│    por ETL                              │
└─────────────────────┬───────────────────┘
                      │  SELECT
                      ▼
┌─────────────────────────────────────────┐
│  Consultas SQL analíticas (5 queries)   │
│  Dashboard matplotlib (4 visualiz.)     │
└─────────────────────────────────────────┘
```

---

## 📁 Estructura del repositorio

```
proyecto_desastres_mexico/
├── README.md                          ← este archivo
├── scripts/
│   ├── 01_schema_ddl.sql              ← esquema estrella (4 dims + 1 fact)
│   ├── 02_dim_estado.sql              ← 32 entidades federativas con coords
│   ├── 03_dim_tiempo.sql              ← años 2020–2025 con clasificación pandemia
│   ├── 04_dim_fenomeno.sql            ← catálogo de 21 fenómenos naturales
│   ├── 05_dim_tipo_evento.sql         ← tipos de declaratoria
│   └── etl_pipeline.py               ← ETL Python end-to-end
├── analisis/
│   └── queries_analiticas.sql         ← 5 queries con SQL avanzado
└── dashboard/
    ├── generar_visualizaciones.py     ← script matplotlib que produce las 4 PNGs
    └── img/
        ├── evolucion_anual.png
        ├── top_estados.png
        ├── fenomenos_frecuentes.png
        └── mapa_afectaciones.png
```

---

## 🔧 Cómo ejecutar

### 1. Setup del schema en Aurora

Desde DBeaver o psql, ejecutar los scripts en orden:

```bash
psql "postgresql://postgres:TU_PASSWORD@aurora-modX.cluster-XXX.us-east-1.rds.amazonaws.com:5432/northwind" \
     -f scripts/01_schema_ddl.sql
psql ... -f scripts/02_dim_estado.sql
psql ... -f scripts/03_dim_tiempo.sql
psql ... -f scripts/04_dim_fenomeno.sql
psql ... -f scripts/05_dim_tipo_evento.sql
```

### 2. Descargar los CSVs y ejecutar el ETL

Descargar manualmente los tres archivos desde:
[https://datos.gob.mx/busca/dataset/gestion-de-riesgos](https://datos.gob.mx/busca/dataset/gestion-de-riesgos)

Guardarlos en una carpeta `data/` local, luego:

```bash
pip install pandas sqlalchemy psycopg2-binary requests tqdm

python scripts/etl_pipeline.py \
    --host     aurora-modX.cluster-XXX.us-east-1.rds.amazonaws.com \
    --password TU_PASSWORD \
    --database northwind \
    --mode     csv \
    --csv-emergencia data/emergencias.csv \
    --csv-desastre   data/desastres.csv \
    --csv-preventivo data/preventivos.csv
```

### 3. Regenerar las visualizaciones

```bash
pip install matplotlib pandas numpy sqlalchemy psycopg2-binary

export AURORA_HOST=aurora-modX.cluster-XXX.us-east-1.rds.amazonaws.com
export AURORA_PASSWORD=TU_PASSWORD
python dashboard/generar_visualizaciones.py
```

Si `AURORA_HOST` no está definido, el script genera datos sintéticos coherentes para previsualización sin conexión.

---

## 🏗️ Modelo dimensional

### Esquema estrella

```
                        ┌──────────────────┐
                        │   dim_tiempo     │
                        │                  │
                        │ id_tiempo PK     │
                        │ anio             │
                        │ periodo          │
                        │ es_postpandemia  │
                        └────────┬─────────┘
                                 │
┌──────────────────┐    ┌────────┴──────────────────────┐    ┌──────────────────┐
│   dim_estado     │    │   fact_eventos_desastres       │    │   dim_fenomeno   │
│                  │    │                                │    │                  │
│ id_estado PK     │◄───│ id_evento PK                  │───►│ id_fenomeno PK   │
│ clave_estado     │    │ id_estado FK                  │    │ tipo_fenomeno    │
│ estado           │    │ id_tiempo FK                  │    │ categoria        │
│ region           │    │ id_fenomeno FK                │    │ descripcion      │
│ latitud          │    │ id_tipo_evento FK             │    └──────────────────┘
│ longitud         │    │                                │
└──────────────────┘    │ municipios_afectados           │    ┌──────────────────┐
                        │ poblacion_afectada             │    │ dim_tipo_evento  │
                        │ poblacion_atendida             │◄───│                  │
                        │ costo_total                    │    │ id_tipo_evento PK│
                        │ cantidad_eventos               │    │ tipo_evento      │
                        └────────────────────────────────┘    │ (Emergencia /   │
                                                               │  Desastre /     │
                                                               │  Preventivo)    │
                                                               └──────────────────┘
```

### Decisiones de diseño

**Grano de la fact:** una fila por declaratoria registrada. Se eligió este nivel porque representa el máximo detalle disponible en el origen de datos y permite agregar libremente a cualquier nivel superior (por año, por estado, por fenómeno).

**`dim_tiempo` con campo `es_postpandemia`:** la pregunta analítica central del proyecto es la comparación pre/post pandemia. Pre-calcular este flag en la dimensión permite hacer `WHERE dt.es_postpandemia = TRUE` sin necesidad de transformaciones en cada query.

**`dim_fenomeno` con campo `categoria`:** los fenómenos naturales pertenecen a categorías analíticamente distintas (Hidrometeorológico vs. Geológico). Tenerlo en la dimensión permite `GROUP BY df.categoria` de forma limpia y soporta futuros análisis por tipo de riesgo.

**`dim_estado` con coordenadas:** incluir latitud y longitud directamente en la dimensión permite construir visualizaciones geoespaciales (mapa de calor) sin necesidad de un join adicional a una tabla de referencia geográfica.

**`dim_tipo_evento` separada:** aunque solo tiene 3 valores (Emergencia, Desastre, Preventivo), separarla de la fact permite comparar los tres tipos dentro del mismo modelo sin necesidad de tablas ni queries separadas. Aplica el principio Kimball de congruencia de dimensiones.

---

## 💻 SQL avanzado destacado

Cinco queries en [`analisis/queries_analiticas.sql`](analisis/queries_analiticas.sql):

### 1. Top 10 estados con mayor incremento post-pandemia (CTE + SUM CASE)

```sql
WITH declaratorias_periodo AS (
    SELECT
        de.estado,
        SUM(CASE WHEN dt.es_postpandemia = FALSE THEN f.cantidad_eventos ELSE 0 END) AS eventos_pandemia,
        SUM(CASE WHEN dt.es_postpandemia = TRUE  THEN f.cantidad_eventos ELSE 0 END) AS eventos_postpandemia
    FROM      fact_eventos_desastres f
    JOIN      dim_estado de USING (id_estado)
    JOIN      dim_tiempo dt USING (id_tiempo)
    GROUP BY  de.estado
)
SELECT estado, eventos_pandemia, eventos_postpandemia,
       eventos_postpandemia - eventos_pandemia AS incremento_absoluto
FROM   declaratorias_periodo
ORDER  BY incremento_absoluto DESC LIMIT 10;
```

### 2. Crecimiento año a año por tipo de evento (CTE + LAG)

```sql
WITH anual AS (
    SELECT dte.tipo_evento, dt.anio,
           SUM(f.cantidad_eventos) AS total_declaratorias
    FROM   fact_eventos_desastres f
    JOIN   dim_tipo_evento dte USING (id_tipo_evento)
    JOIN   dim_tiempo      dt  USING (id_tiempo)
    GROUP  BY dte.tipo_evento, dt.anio
)
SELECT tipo_evento, anio, total_declaratorias,
       LAG(total_declaratorias) OVER (PARTITION BY tipo_evento ORDER BY anio) AS anio_anterior,
       total_declaratorias - LAG(total_declaratorias) OVER (
           PARTITION BY tipo_evento ORDER BY anio
       ) AS delta
FROM   anual
ORDER  BY tipo_evento, anio;
```

### 3. Comparación de fenómenos pre vs. post pandemia (CTE + PIVOT con SUM CASE)

Identifica qué fenómenos aumentaron su frecuencia después de la pandemia.

### 4. Ranking de fenómenos por región (CTE + DENSE_RANK)

Rankea los fenómenos más frecuentes dentro de cada región (Norte, Centro, Sur-Sureste).

### 5. Participación estatal en el total nacional (SUM OVER acumulado)

Calcula qué porcentaje del total nacional representa cada estado y el porcentaje acumulado (análisis tipo Pareto).

---

## 📊 Visualizaciones

Cuatro vistas generadas con matplotlib desde Aurora (o datos sintéticos en modo offline):

### 1. Evolución anual de declaratorias

![Evolución anual](dashboard/img/evolucion_anual.png)

Comparativa de declaratorias de Emergencia vs. Desastre por año, con línea divisoria pandemia/post-pandemia. Permite identificar la tendencia creciente post-2021.

### 2. Top estados con mayor incremento post-pandemia

![Top estados](dashboard/img/top_estados.png)

Barras horizontales que comparan el número de declaratorias durante la pandemia (2020–2021) versus post-pandemia (2022–2025), para los 10 estados con mayor incremento absoluto.

### 3. Fenómenos más frecuentes (2020–2025)

![Fenómenos](dashboard/img/fenomenos_frecuentes.png)

Ranking de los 12 fenómenos naturales con más declaratorias acumuladas. El color distingue entre fenómenos hidrometeorológicos (rojo) y geológicos (naranja).

### 4. Mapa de intensidad de afectaciones

![Mapa](dashboard/img/mapa_afectaciones.png)

Cada estado se representa como un punto cuyo tamaño y color reflejan el total de declaratorias. Los 5 estados más afectados están anotados.

---

## 🔍 Hallazgos principales

> *Nota: los hallazgos definitivos se actualizarán una vez que el ETL esté corriendo contra los datos reales de Aurora. Los patrones descritos corresponden a los datos sintéticos de previsualización.*

1. **Tendencia creciente post-pandemia:** el número de declaratorias de emergencia aumentó ~50% entre 2020 y 2025, con un quiebre claro a partir de 2022.
2. **Estados del sur concentran el mayor incremento:** Guerrero, Veracruz y Oaxaca lideran el crecimiento en declaratorias, consistente con la mayor exposición a huracanes y lluvias extremas en el litoral del Pacífico y Golfo.
3. **Los fenómenos hidrometeorológicos dominan:** lluvias, inundaciones y tormentas severas representan más del 70% del total de declaratorias en el período.
4. **Frentes fríos e incendios forestales muestran el mayor crecimiento porcentual** en la comparación pre/post pandemia, posiblemente asociado a los efectos acumulados del cambio climático.

---

## 📚 Referencias

- [Datos Abiertos — Gestión de Riesgos (datos.gob.mx)](https://datos.gob.mx/busca/dataset/gestion-de-riesgos)
- [CENAPRED — Atlas Nacional de Riesgos](http://www.atlasnacionalderiesgos.gob.mx/)
- [FONDEN — Reglas de Operación (DOF)](https://www.gob.mx/segob/documentos/reglas-de-operacion-del-fondo-de-desastres-naturales)
- Material del módulo: Tema 02 (Modelo dimensional), Tema 04 (ETL Python), Tema 05 (SQL avanzado)

---

<p align="center">
<a href="#">← Volver al inicio</a> | <a href="#">Ver rúbrica</a>
</p>
