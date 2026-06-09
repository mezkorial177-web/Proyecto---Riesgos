#!/usr/bin/env python3
"""
ETL Pipeline — Gestión de Riesgos y Desastres Naturales en México (2020–2025)

Descarga los tres datasets de la API de Datos Abiertos del Gobierno de México,
los transforma al modelo dimensional estrella y los carga a Aurora PostgreSQL.

Uso:
    python etl_pipeline.py \\
        --host  aurora-modX.cluster-XXX.us-east-1.rds.amazonaws.com \\
        --password TU_PASSWORD \\
        --database northwind

Prerrequisito: las dimensiones deben estar ya pobladas con los scripts 02–05.

Fuentes:
    Declaratorias de Emergencia  → datos.gob.mx  (recurso ID: declaratorias-emergencia)
    Declaratorias de Desastre    → datos.gob.mx  (recurso ID: declaratorias-desastre)
    Proyectos Preventivos        → datos.gob.mx  (recurso ID: proyectos-preventivos)
"""

import argparse
import io
import logging
import sys

import pandas as pd
import requests
from sqlalchemy import create_engine, text
from sqlalchemy.types import Integer, BigInteger, Numeric, SmallInteger

logger = logging.getLogger("etl_desastres")

# =============================================================================
# URLs de la API de Datos Abiertos del Gobierno de México
# Endpoint CKAN: https://datos.gob.mx/busca/api/action/datastore_search
# Los resource_id se obtienen desde la página de cada dataset en datos.gob.mx
# =============================================================================

DATASETS = {
    "Emergencia": {
        "url": "https://datos.gob.mx/busca/api/action/datastore_search",
        "resource_id": "declaratorias-emergencia-resource-id",  # reemplaza con ID real
        "tipo_evento": "Emergencia",
    },
    "Desastre": {
        "url": "https://datos.gob.mx/busca/api/action/datastore_search",
        "resource_id": "declaratorias-desastre-resource-id",    # reemplaza con ID real
        "tipo_evento": "Desastre",
    },
    "Preventivo": {
        "url": "https://datos.gob.mx/busca/api/action/datastore_search",
        "resource_id": "proyectos-preventivos-resource-id",     # reemplaza con ID real
        "tipo_evento": "Preventivo",
    },
}

# Columnas esperadas en cada CSV fuente (ajustar según el esquema real de datos.gob.mx)
COLUMN_MAP = {
    "ENTIDAD":               "estado_raw",
    "FENOMENO":              "fenomeno_raw",
    "ANIO":                  "anio",
    "MUNICIPIOS_AFECTADOS":  "municipios_afectados",
    "POBLACION_AFECTADA":    "poblacion_afectada",
    "POBLACION_ATENDIDA":    "poblacion_atendida",
    "MONTO_APROBADO":        "costo_total",
}

YEARS_OF_INTEREST = range(2020, 2026)


# =============================================================================
# Extract
# =============================================================================

def extract_from_api(dataset_name: str, config: dict) -> pd.DataFrame:
    """
    Descarga todos los registros disponibles del endpoint CKAN usando paginación.
    El endpoint devuelve máximo 100 registros por petición.
    """
    logger.info("Extrayendo dataset: %s", dataset_name)
    all_records = []
    offset = 0
    limit = 1000

    while True:
        params = {
            "resource_id": config["resource_id"],
            "limit": limit,
            "offset": offset,
        }
        response = requests.get(config["url"], params=params, timeout=60)
        response.raise_for_status()
        data = response.json()

        if not data.get("success"):
            raise ValueError(f"API respondió con error para {dataset_name}: {data}")

        records = data["result"]["records"]
        if not records:
            break

        all_records.extend(records)
        offset += limit
        logger.info("  %s: %d registros acumulados", dataset_name, len(all_records))

        # Si ya no hay más páginas
        if len(records) < limit:
            break

    df = pd.DataFrame(all_records)
    logger.info("  %s: total %d filas descargadas", dataset_name, len(df))
    return df


def extract_from_csv(filepath: str, tipo_evento: str) -> pd.DataFrame:
    """
    Alternativa a la API: carga directamente desde un CSV descargado manualmente.
    Útil cuando datos.gob.mx no tiene API pública para el recurso.

    Descarga manual: https://datos.gob.mx/busca/dataset/gestion-de-riesgos
    """
    logger.info("Cargando CSV local: %s (%s)", filepath, tipo_evento)
    df = pd.read_csv(filepath, encoding="utf-8-sig")
    df["tipo_evento_raw"] = tipo_evento
    logger.info("  %d filas cargadas desde CSV", len(df))
    return df


# =============================================================================
# Transform
# =============================================================================

def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Estandariza nombres de columnas a minúsculas sin espacios."""
    df.columns = (
        df.columns
        .str.strip()
        .str.upper()
        .str.replace(" ", "_")
        .str.replace("Á", "A").str.replace("É", "E")
        .str.replace("Í", "I").str.replace("Ó", "O")
        .str.replace("Ú", "U").str.replace("Ñ", "N")
    )
    return df


def transform(df: pd.DataFrame, tipo_evento: str) -> pd.DataFrame:
    """
    Pipeline de transformación completo:
    1. Normaliza columnas
    2. Renombra al esquema interno
    3. Filtra años de interés (2020–2025)
    4. Limpia nulos y tipos
    5. Agrega columna tipo_evento
    """
    df = normalize_columns(df)

    # Renombrar columnas usando el mapeo; ignorar las que no existan en el DataFrame
    existing_map = {k: v for k, v in COLUMN_MAP.items() if k in df.columns}
    df = df.rename(columns=existing_map)

    # Asegurar que anio existe y es numérico
    if "anio" not in df.columns:
        # Intentar extraer año de una columna de fecha si existe
        date_cols = [c for c in df.columns if "FECHA" in c or "DATE" in c]
        if date_cols:
            df["anio"] = pd.to_datetime(df[date_cols[0]], errors="coerce").dt.year
        else:
            raise ValueError("No se encontró columna de año o fecha en el dataset.")

    df["anio"] = pd.to_numeric(df["anio"], errors="coerce")
    df = df[df["anio"].isin(YEARS_OF_INTEREST)].copy()

    # Limpiar métricas numéricas
    for col in ["municipios_afectados", "poblacion_afectada", "poblacion_atendida"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0).astype(int)
        else:
            df[col] = 0

    if "costo_total" in df.columns:
        df["costo_total"] = pd.to_numeric(df["costo_total"], errors="coerce").fillna(0.0)
    else:
        df["costo_total"] = 0.0

    df["tipo_evento"] = tipo_evento

    # Normalizar texto en estado y fenómeno para el merge posterior
    if "estado_raw" in df.columns:
        df["estado_raw"] = df["estado_raw"].str.strip().str.title()
    if "fenomeno_raw" in df.columns:
        df["fenomeno_raw"] = df["fenomeno_raw"].str.strip().str.title()

    logger.info("  Transformado: %d filas para %s (años %s–%s)",
                len(df), tipo_evento, min(YEARS_OF_INTEREST), max(YEARS_OF_INTEREST))
    return df


def resolve_surrogate_keys(df: pd.DataFrame, engine) -> pd.DataFrame:
    """
    Sustituye los valores textuales (estado, fenómeno, tipo, año) por
    las surrogate keys de las dimensiones en Aurora.
    """
    estados    = pd.read_sql("SELECT id_estado, estado FROM desastres.dim_estado", engine)
    tiempos    = pd.read_sql("SELECT id_tiempo, anio FROM desastres.dim_tiempo", engine)
    fenomenos  = pd.read_sql("SELECT id_fenomeno, tipo_fenomeno FROM desastres.dim_fenomeno", engine)
    tipos      = pd.read_sql("SELECT id_tipo_evento, tipo_evento FROM desastres.dim_tipo_evento", engine)

    # Merge por estado
    df = df.merge(
        estados.rename(columns={"estado": "estado_raw"}),
        on="estado_raw", how="left"
    )

    # Merge por año → id_tiempo
    df["anio"] = df["anio"].astype(int)
    df = df.merge(tiempos, on="anio", how="left")

    # Merge por fenómeno
    df = df.merge(
        fenomenos.rename(columns={"tipo_fenomeno": "fenomeno_raw"}),
        on="fenomeno_raw", how="left"
    )

    # Merge por tipo de evento
    df = df.merge(tipos, on="tipo_evento", how="left")

    # Reportar registros sin match (para debugging)
    sin_estado   = df["id_estado"].isna().sum()
    sin_fenomeno = df["id_fenomeno"].isna().sum()
    if sin_estado > 0:
        logger.warning("  %d registros sin match en dim_estado", sin_estado)
    if sin_fenomeno > 0:
        logger.warning("  %d registros sin match en dim_fenomeno", sin_fenomeno)

    # Solo cargar registros con todas las claves resueltas
    df = df.dropna(subset=["id_estado", "id_tiempo", "id_fenomeno", "id_tipo_evento"])

    fact_cols = [
        "id_estado", "id_tiempo", "id_fenomeno", "id_tipo_evento",
        "municipios_afectados", "poblacion_afectada", "poblacion_atendida",
        "costo_total"
    ]
    return df[fact_cols].copy()


# =============================================================================
# Load
# =============================================================================

def load(df: pd.DataFrame, engine, chunksize: int = 5000):
    """Carga incrementalmente a fact_eventos_desastres con method='multi'."""
    logger.info("Cargando %s filas a fact_eventos_desastres", f"{len(df):,}")

    df["cantidad_eventos"] = 1

    df.to_sql(
        "fact_eventos_desastres",
        engine,
        schema="desastres",
        if_exists="append",
        index=False,
        method="multi",
        chunksize=chunksize,
        dtype={
            "id_estado":             Integer(),
            "id_tiempo":             Integer(),
            "id_fenomeno":           Integer(),
            "id_tipo_evento":        SmallInteger(),
            "municipios_afectados":  Integer(),
            "poblacion_afectada":    BigInteger(),
            "poblacion_atendida":    BigInteger(),
            "costo_total":           Numeric(18, 2),
            "cantidad_eventos":      Integer(),
        },
    )
    logger.info("  Carga completada.")


# =============================================================================
# Validate
# =============================================================================

def validate(engine):
    """Validaciones post-carga para verificar integridad básica."""
    logger.info("Ejecutando validaciones post-carga...")

    resumen = pd.read_sql(text("""
        SELECT
            dt.tipo_evento,
            dti.anio,
            COUNT(*)                            AS total_declaratorias,
            SUM(f.municipios_afectados)         AS total_municipios,
            SUM(f.poblacion_afectada)           AS total_poblacion,
            ROUND(SUM(f.costo_total) / 1e9, 2) AS costo_total_miles_millones
        FROM      desastres.fact_eventos_desastres f
        JOIN      desastres.dim_tipo_evento  dt  USING (id_tipo_evento)
        JOIN      desastres.dim_tiempo       dti USING (id_tiempo)
        GROUP BY  dt.tipo_evento, dti.anio
        ORDER BY  dti.anio, dt.tipo_evento
    """), engine)

    logger.info("Resumen post-carga:\n%s", resumen.to_string(index=False))

    # Sanity: ningún año fuera del rango 2020–2025
    anios_invalidos = pd.read_sql(text("""
        SELECT COUNT(*) AS n
        FROM desastres.fact_eventos_desastres f
        JOIN desastres.dim_tiempo dt USING (id_tiempo)
        WHERE dt.anio NOT BETWEEN 2020 AND 2025
    """), engine).iloc[0, 0]

    assert anios_invalidos == 0, f"{anios_invalidos} registros con año fuera de rango"
    logger.info("✓ Sin registros fuera del rango 2020–2025")

    # Sanity: no hay claves foráneas nulas
    nulos = pd.read_sql(text("""
        SELECT COUNT(*) AS n
        FROM desastres.fact_eventos_desastres
        WHERE id_estado IS NULL OR id_tiempo IS NULL
           OR id_fenomeno IS NULL OR id_tipo_evento IS NULL
    """), engine).iloc[0, 0]

    assert nulos == 0, f"{nulos} registros con claves foráneas nulas"
    logger.info("✓ Sin claves foráneas nulas")


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="ETL: Desastres Naturales México → Aurora PostgreSQL"
    )
    parser.add_argument("--host",     required=True,  help="Host de Aurora")
    parser.add_argument("--password", required=True,  help="Contraseña de Aurora")
    parser.add_argument("--database", default="northwind")
    parser.add_argument("--mode",     choices=["api", "csv"], default="csv",
                        help="Fuente de datos: api (CKAN) o csv (archivos locales)")
    parser.add_argument("--csv-emergencia", default="data/emergencias.csv")
    parser.add_argument("--csv-desastre",   default="data/desastres.csv")
    parser.add_argument("--csv-preventivo", default="data/preventivos.csv")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    )

    engine = create_engine(
        f"postgresql+psycopg2://postgres:{args.password}@{args.host}:5432/{args.database}"
    )

    try:
        # Acumulamos todos los registros en un solo DataFrame antes de cargar
        frames = []

        if args.mode == "api":
            for nombre, config in DATASETS.items():
                df_raw = extract_from_api(nombre, config)
                df_clean = transform(df_raw, config["tipo_evento"])
                frames.append(df_clean)
        else:
            # Modo CSV local (más común durante desarrollo)
            csv_sources = [
                (args.csv_emergencia, "Emergencia"),
                (args.csv_desastre,   "Desastre"),
                (args.csv_preventivo, "Preventivo"),
            ]
            for filepath, tipo in csv_sources:
                df_raw = extract_from_csv(filepath, tipo)
                df_clean = transform(df_raw, tipo)
                frames.append(df_clean)

        df_all = pd.concat(frames, ignore_index=True)
        logger.info("Total registros transformados: %d", len(df_all))

        # Resolver surrogate keys
        df_fact = resolve_surrogate_keys(df_all, engine)
        logger.info("Total registros con claves resueltas: %d", len(df_fact))

        # Cargar a Aurora
        load(df_fact, engine)

        # Validar
        validate(engine)

        logger.info("ETL completado correctamente ✓")

    except Exception as exc:
        logger.exception("ETL falló: %s", exc)
        sys.exit(1)


if __name__ == "__main__":
    main()
