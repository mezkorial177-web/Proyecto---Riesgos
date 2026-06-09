#!/usr/bin/env python3
"""
Dashboard — Desastres Naturales México 2020–2025
Genera 4 visualizaciones estáticas con matplotlib.

Modos:
  - Con AURORA_HOST definido: consulta Aurora PostgreSQL
  - Sin AURORA_HOST: genera datos sintéticos coherentes con los patrones reales
    (útil para previsualizar sin conexión a la base)

Uso:
    # Contra Aurora:
    export AURORA_HOST=aurora-modX.cluster-XXX.us-east-1.rds.amazonaws.com
    export AURORA_PASSWORD=TU_PASSWORD
    python dashboard/generar_visualizaciones.py

    # Modo offline (datos sintéticos):
    python dashboard/generar_visualizaciones.py
"""

import os
import pathlib
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import matplotlib.patches as mpatches
from matplotlib.colors import LinearSegmentedColormap

# Directorio de salida de imágenes
IMG_DIR = pathlib.Path(__file__).parent / "img"
IMG_DIR.mkdir(exist_ok=True)

# Paleta institucional
COLOR_PRIMARIO   = "#C0392B"   # rojo desastre
COLOR_SECUNDARIO = "#E67E22"   # naranja alerta
COLOR_TERCIARIO  = "#2980B9"   # azul emergencia
COLOR_NEUTRO     = "#7F8C8D"   # gris
COLOR_FONDO      = "#F8F9FA"
COLORES_ANIO     = ["#2C3E50", "#2980B9", "#27AE60", "#E67E22", "#C0392B", "#8E44AD"]

plt.rcParams.update({
    "font.family":        "DejaVu Sans",
    "axes.spines.top":    False,
    "axes.spines.right":  False,
    "axes.facecolor":     COLOR_FONDO,
    "figure.facecolor":   "white",
    "axes.grid":          True,
    "grid.alpha":         0.4,
    "grid.linestyle":     "--",
})


# =============================================================================
# Carga de datos
# =============================================================================

def get_engine():
    """Devuelve engine de SQLAlchemy si AURORA_HOST está configurado."""
    host = os.getenv("AURORA_HOST")
    if not host:
        return None
    password = os.getenv("AURORA_PASSWORD", "")
    database = os.getenv("AURORA_DATABASE", "northwind")
    from sqlalchemy import create_engine
    return create_engine(
        f"postgresql+psycopg2://postgres:{password}@{host}:5432/{database}"
    )


def load_data(engine):
    """Carga los cuatro datasets para las visualizaciones desde Aurora."""
    evolucion = pd.read_sql("""
        SELECT
            dt.anio,
            dte.tipo_evento,
            SUM(f.cantidad_eventos)     AS total_declaratorias,
            SUM(f.municipios_afectados) AS municipios_afectados,
            SUM(f.poblacion_afectada)   AS poblacion_afectada
        FROM desastres.fact_eventos_desastres f
        JOIN desastres.dim_tiempo      dt  USING (id_tiempo)
        JOIN desastres.dim_tipo_evento dte USING (id_tipo_evento)
        GROUP BY dt.anio, dte.tipo_evento
        ORDER BY dt.anio
    """, engine)

    top_estados = pd.read_sql("""
        WITH por_periodo AS (
            SELECT
                de.estado,
                SUM(CASE WHEN dt.es_postpandemia = FALSE THEN f.cantidad_eventos ELSE 0 END) AS pre,
                SUM(CASE WHEN dt.es_postpandemia = TRUE  THEN f.cantidad_eventos ELSE 0 END) AS post
            FROM desastres.fact_eventos_desastres f
            JOIN desastres.dim_estado de  USING (id_estado)
            JOIN desastres.dim_tiempo dt  USING (id_tiempo)
            GROUP BY de.estado
        )
        SELECT estado,
               pre  AS eventos_pre,
               post AS eventos_post,
               post - pre AS incremento
        FROM  por_periodo
        ORDER BY incremento DESC
        LIMIT 10
    """, engine)

    fenomenos = pd.read_sql("""
        SELECT
            df.tipo_fenomeno,
            df.categoria,
            SUM(f.cantidad_eventos)   AS total,
            SUM(f.poblacion_afectada) AS poblacion_afectada
        FROM desastres.fact_eventos_desastres f
        JOIN desastres.dim_fenomeno df USING (id_fenomeno)
        GROUP BY df.tipo_fenomeno, df.categoria
        ORDER BY total DESC
        LIMIT 12
    """, engine)

    mapa_estados = pd.read_sql("""
        SELECT
            de.estado, de.latitud, de.longitud, de.region,
            SUM(f.cantidad_eventos) AS total_eventos
        FROM desastres.fact_eventos_desastres f
        JOIN desastres.dim_estado de USING (id_estado)
        GROUP BY de.estado, de.latitud, de.longitud, de.region
    """, engine)

    return evolucion, top_estados, fenomenos, mapa_estados


def synthetic_data():
    """Genera datos sintéticos coherentes con patrones reales de FONDEN."""
    np.random.seed(42)
    anios = range(2020, 2026)
    tipos = ["Emergencia", "Desastre"]

    # Tendencia creciente post-pandemia
    base_emerg = [120, 115, 135, 158, 172, 181]
    base_desas = [85,  80,  95,  110, 124, 133]

    rows = []
    for i, anio in enumerate(anios):
        rows.append({"anio": anio, "tipo_evento": "Emergencia",
                     "total_declaratorias": base_emerg[i],
                     "municipios_afectados": base_emerg[i] * 8,
                     "poblacion_afectada": base_emerg[i] * 35000})
        rows.append({"anio": anio, "tipo_evento": "Desastre",
                     "total_declaratorias": base_desas[i],
                     "municipios_afectados": base_desas[i] * 12,
                     "poblacion_afectada": base_desas[i] * 70000})
    evolucion = pd.DataFrame(rows)

    estados = [
        "Guerrero", "Veracruz", "Oaxaca", "Tabasco", "Chiapas",
        "Hidalgo", "Puebla", "Sinaloa", "Jalisco", "Tamaulipas"
    ]
    pre  = np.random.randint(20, 60, len(estados))
    post = pre + np.random.randint(10, 50, len(estados))
    top_estados = pd.DataFrame({
        "estado": estados,
        "eventos_pre":  pre,
        "eventos_post": post,
        "incremento":   post - pre,
    }).sort_values("incremento", ascending=False)

    fenomenos_data = {
        "tipo_fenomeno": ["Lluvias", "Inundación", "Tormenta Severa", "Huracán",
                          "Sequía", "Incendio Forestal", "Frente Frío", "Viento",
                          "Granizo", "Sismo", "Helada", "Deslizamiento"],
        "categoria":     ["Hidrometeorológico"]*9 + ["Geológico"]*3,
        "total":         [520, 410, 310, 290, 180, 155, 140, 120, 95, 85, 70, 55],
        "poblacion_afectada": [i * 45000 for i in [520, 410, 310, 290, 180, 155, 140, 120, 95, 85, 70, 55]],
    }
    fenomenos = pd.DataFrame(fenomenos_data)

    coords = {
        "Guerrero":     (17.44, -99.55), "Veracruz":    (19.17, -96.13),
        "Oaxaca":       (17.07, -96.73), "Tabasco":     (17.99, -92.95),
        "Chiapas":      (16.76, -93.13), "Jalisco":     (20.66, -103.35),
        "Sinaloa":      (25.82, -108.22),"Tamaulipas":  (24.27, -98.84),
        "Michoacán":    (19.70, -101.18),"Hidalgo":     (20.09, -98.76),
        "Puebla":       (19.04, -98.21), "Estado de México": (19.36, -99.85),
        "Sonora":       (29.30, -110.33),"Chihuahua":   (28.64, -106.09),
        "Baja California": (30.84, -115.28), "Coahuila":   (27.29, -102.07),
        "Nuevo León":   (25.59, -99.99), "Durango":     (24.03, -104.65),
        "Zacatecas":    (22.77, -102.58),"San Luis Potosí": (22.16, -100.99),
        "Guanajuato":   (21.02, -101.26),"Querétaro":   (20.59, -100.39),
        "Aguascalientes": (21.88, -102.29),"Nayarit":   (21.75, -104.85),
        "Colima":       (19.25, -103.72),"Morelos":     (18.92, -99.22),
        "Tlaxcala":     (19.32, -98.24), "Ciudad de México": (19.43, -99.13),
        "Quintana Roo": (19.18, -88.48), "Yucatán":    (20.71, -89.09),
        "Campeche":     (19.83, -90.53), "Baja California Sur": (26.04, -111.67),
    }
    estados_todos = list(coords.keys())
    total_ev = np.random.randint(15, 140, len(estados_todos))
    region_map = {
        "Guerrero": "Sur-Sureste", "Veracruz": "Sur-Sureste", "Oaxaca": "Sur-Sureste",
        "Tabasco": "Sur-Sureste", "Chiapas": "Sur-Sureste", "Jalisco": "Centro",
        "Sinaloa": "Norte", "Tamaulipas": "Norte", "Michoacán": "Centro",
        "Hidalgo": "Centro", "Puebla": "Centro", "Estado de México": "Centro",
        "Sonora": "Norte", "Chihuahua": "Norte", "Baja California": "Norte",
        "Coahuila": "Norte", "Nuevo León": "Norte", "Durango": "Norte",
        "Zacatecas": "Norte", "San Luis Potosí": "Centro", "Guanajuato": "Centro",
        "Querétaro": "Centro", "Aguascalientes": "Centro", "Nayarit": "Norte",
        "Colima": "Centro", "Morelos": "Centro", "Tlaxcala": "Centro",
        "Ciudad de México": "Centro", "Quintana Roo": "Sur-Sureste",
        "Yucatán": "Sur-Sureste", "Campeche": "Sur-Sureste",
        "Baja California Sur": "Norte",
    }
    mapa_estados = pd.DataFrame({
        "estado":        estados_todos,
        "latitud":       [coords[e][0] for e in estados_todos],
        "longitud":      [coords[e][1] for e in estados_todos],
        "region":        [region_map.get(e, "Centro") for e in estados_todos],
        "total_eventos": total_ev,
    })

    return evolucion, top_estados, fenomenos, mapa_estados


# =============================================================================
# Visualización 1: Evolución anual de declaratorias
# =============================================================================

def viz_evolucion_anual(evolucion: pd.DataFrame):
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    fig.suptitle("Evolución Anual de Declaratorias de Emergencia y Desastre\nMéxico 2020–2025",
                 fontsize=14, fontweight="bold", y=1.02)

    for ax, tipo, color in zip(axes, ["Emergencia", "Desastre"],
                                [COLOR_TERCIARIO, COLOR_PRIMARIO]):
        df = evolucion[evolucion["tipo_evento"] == tipo].sort_values("anio")
        ax.bar(df["anio"], df["total_declaratorias"], color=color, alpha=0.85,
               edgecolor="white", linewidth=0.8, label=tipo)
        ax.plot(df["anio"], df["total_declaratorias"], marker="o", color=color,
                linewidth=2, markersize=6)

        # Línea divisoria pandemia / post-pandemia
        ax.axvline(x=2021.5, color=COLOR_NEUTRO, linestyle="--", linewidth=1.5, alpha=0.8)
        ax.text(2020.8, ax.get_ylim()[1] * 0.92, "Pandemia", fontsize=8,
                color=COLOR_NEUTRO, alpha=0.9)
        ax.text(2022.1, ax.get_ylim()[1] * 0.92, "Post-pandemia", fontsize=8,
                color=COLOR_NEUTRO, alpha=0.9)

        for x, y in zip(df["anio"], df["total_declaratorias"]):
            ax.text(x, y + 2, str(int(y)), ha="center", fontsize=9, fontweight="bold")

        ax.set_title(f"Declaratorias de {tipo}", fontsize=12, fontweight="bold")
        ax.set_xlabel("Año")
        ax.set_ylabel("Número de declaratorias")
        ax.set_xticks(df["anio"])

    plt.tight_layout()
    out = IMG_DIR / "evolucion_anual.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  ✓ Guardado: {out}")


# =============================================================================
# Visualización 2: Top estados con mayor incremento post-pandemia
# =============================================================================

def viz_top_estados(top_estados: pd.DataFrame):
    df = top_estados.sort_values("incremento", ascending=True).tail(10)

    fig, ax = plt.subplots(figsize=(12, 6))
    y = range(len(df))
    ax.barh(y, df["eventos_post"], color=COLOR_PRIMARIO, alpha=0.85,
            label="Post-pandemia (2022–2025)")
    ax.barh(y, df["eventos_pre"], color=COLOR_TERCIARIO, alpha=0.85,
            label="Pandemia (2020–2021)")

    ax.set_yticks(list(y))
    ax.set_yticklabels(df["estado"], fontsize=10)
    ax.set_xlabel("Número de declaratorias")
    ax.set_title("Top 10 Estados con Mayor Incremento de Declaratorias\nPost-Pandemia vs. Pandemia",
                 fontsize=13, fontweight="bold")
    ax.legend(loc="lower right")

    # Anotar incremento
    for i, (_, row) in enumerate(df.iterrows()):
        ax.text(row["eventos_post"] + 1, i, f'+{int(row["incremento"])}',
                va="center", fontsize=9, color=COLOR_PRIMARIO, fontweight="bold")

    plt.tight_layout()
    out = IMG_DIR / "top_estados.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  ✓ Guardado: {out}")


# =============================================================================
# Visualización 3: Fenómenos más frecuentes
# =============================================================================

def viz_fenomenos(fenomenos: pd.DataFrame):
    df = fenomenos.sort_values("total", ascending=False).head(12)

    colors = [COLOR_PRIMARIO if c == "Hidrometeorológico" else COLOR_SECUNDARIO
              for c in df["categoria"]]

    fig, ax = plt.subplots(figsize=(12, 6))
    bars = ax.bar(range(len(df)), df["total"], color=colors, alpha=0.88,
                  edgecolor="white", linewidth=0.8)

    ax.set_xticks(range(len(df)))
    ax.set_xticklabels(df["tipo_fenomeno"], rotation=35, ha="right", fontsize=9)
    ax.set_ylabel("Total de declaratorias (2020–2025)")
    ax.set_title("Fenómenos Naturales más Frecuentes en México 2020–2025",
                 fontsize=13, fontweight="bold")

    for bar, val in zip(bars, df["total"]):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 2,
                str(int(val)), ha="center", fontsize=8, fontweight="bold")

    legend_patches = [
        mpatches.Patch(color=COLOR_PRIMARIO, label="Hidrometeorológico"),
        mpatches.Patch(color=COLOR_SECUNDARIO, label="Geológico / Otro"),
    ]
    ax.legend(handles=legend_patches, loc="upper right")

    plt.tight_layout()
    out = IMG_DIR / "fenomenos_frecuentes.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  ✓ Guardado: {out}")


# =============================================================================
# Visualización 4: Mapa de México con intensidad de afectaciones
# =============================================================================

def viz_mapa(mapa_estados: pd.DataFrame):
    fig, ax = plt.subplots(figsize=(12, 8))
    ax.set_facecolor("#D6EAF8")

    cmap = LinearSegmentedColormap.from_list(
        "desastres", ["#FEF9E7", "#F39C12", "#C0392B", "#7B241C"]
    )
    norm = plt.Normalize(
        vmin=mapa_estados["total_eventos"].min(),
        vmax=mapa_estados["total_eventos"].max()
    )

    scatter = ax.scatter(
        mapa_estados["longitud"],
        mapa_estados["latitud"],
        s=mapa_estados["total_eventos"] * 3,
        c=mapa_estados["total_eventos"],
        cmap=cmap,
        norm=norm,
        alpha=0.85,
        edgecolors="white",
        linewidths=0.8,
        zorder=5,
    )

    # Anotar los 5 estados con más eventos
    top5 = mapa_estados.nlargest(5, "total_eventos")
    for _, row in top5.iterrows():
        ax.annotate(
            row["estado"].split()[0],
            xy=(row["longitud"], row["latitud"]),
            xytext=(5, 5), textcoords="offset points",
            fontsize=8, fontweight="bold", color="#7B241C",
            zorder=6,
        )

    cbar = fig.colorbar(scatter, ax=ax, shrink=0.6, pad=0.02)
    cbar.set_label("Total de declaratorias", fontsize=10)

    ax.set_xlim(-118, -86)
    ax.set_ylim(14, 33)
    ax.set_xlabel("Longitud")
    ax.set_ylabel("Latitud")
    ax.set_title("Mapa de Intensidad de Afectaciones por Desastres Naturales\nMéxico 2020–2025",
                 fontsize=13, fontweight="bold")

    # Leyenda de regiones por color de borde (opcional)
    ax.text(-116, 15, "● Tamaño = total declaratorias\n● Color = intensidad de afectación",
            fontsize=8, color="gray", style="italic")

    plt.tight_layout()
    out = IMG_DIR / "mapa_afectaciones.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  ✓ Guardado: {out}")


# =============================================================================
# Main
# =============================================================================

def main():
    engine = get_engine()

    if engine:
        print("Conectando a Aurora PostgreSQL...")
        evolucion, top_estados, fenomenos, mapa_estados = load_data(engine)
    else:
        print("AURORA_HOST no definido → usando datos sintéticos para previsualización.")
        evolucion, top_estados, fenomenos, mapa_estados = synthetic_data()

    print("Generando visualizaciones...")
    viz_evolucion_anual(evolucion)
    viz_top_estados(top_estados)
    viz_fenomenos(fenomenos)
    viz_mapa(mapa_estados)
    print(f"\nListo. Las 4 imágenes se guardaron en: {IMG_DIR.resolve()}")


if __name__ == "__main__":
    main()
