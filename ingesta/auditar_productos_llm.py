#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Auditoría integral producto por producto mediante LLM (cascada costo $0.00).

Valida para CADA EAN asociado a un clúster:
    Producto · Variedad · Presentación (envase) · Contenido neto · Marca
y detecta productos que no pertenecen a un supermercado (descartar).

Cascada: OpenRouter :free (round-robin) ➔ Gemini Flash Lite (ver llm_cascada.py).

Uso:
    python ingesta/auditar_productos_llm.py --limite 300            # prueba corta
    python ingesta/auditar_productos_llm.py --producto Leche         # solo un producto
    python ingesta/auditar_productos_llm.py --workers 3              # auditoría completa
    python ingesta/auditar_productos_llm.py --aplicar                # aplica correcciones a los CSV
    python ingesta/5_subir_supabase.py --clusters-only               # sube a Supabase

El progreso se guarda en un checkpoint JSONL: se puede cortar (Ctrl+C) y reanudar.
"""

import argparse
import json
import re
import shutil
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from typing import Any, Dict, List, Tuple

import pandas as pd

from config import CLUSTERS_DIR, GEMINI_API_KEY, OPENROUTER_API_KEY, PROCESSED_DIR
from llm_cascada import IndicadorVivo, LLMCascada

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

CLUSTERS_CSV = CLUSTERS_DIR / "producto_clusters.csv"
ITEMS_CSV = CLUSTERS_DIR / "producto_cluster_items.csv"
CATALOGO_CSV = PROCESSED_DIR / "catalogo_productos.csv"
CHECKPOINT = CLUSTERS_DIR / "auditoria_productos_llm.jsonl"
REPORTE_CSV = CLUSTERS_DIR / "auditoria_productos_llm_correcciones.csv"

ENVASES_VALIDOS = [
    "Botella", "Lata", "Cartón (Tetra Brik)", "Sachet", "Doypack", "Frasco", "Pote",
    "Paquete", "Bolsa", "Caja", "Bidón", "Blister", "Tubo", "Aerosol", "Bandeja",
    "Granel", "Unidad",
]

# "sin" y "con" NO se eliminan: cambian el producto (Bebida sin Azúcar, Agua con Gas).
STOPWORDS_ES = {
    "el", "la", "los", "las", "un", "una", "unos", "unas", "del", "al", "de", "y", "e",
    "o", "u", "a", "en", "por", "para", "ante", "tras", "que", "x", "su", "sus",
}

UNIDADES = {
    "l": "litro", "lt": "litro", "lts": "litro", "litros": "litro", "ltr": "litro",
    "gr": "g", "grs": "g", "gramos": "g", "kgs": "kg", "kilo": "kg",
    "cc": "ml", "cm3": "ml", "mililitros": "ml",
    "un": "u", "unidad": "u", "unidades": "u", "uni": "u",
}

PROMPT_SISTEMA = f"""Sos auditor experto en catálogos de supermercados de Argentina.
Recibís líneas: i|descripcion_original|marca_sepa|cantidad_sepa => producto|variedad|envase|contenido|marca
(la parte tras "=>" es la clasificación actual a validar).

Validá cada campo con estas reglas:
1. producto: Sustantivo formal y específico de qué es el artículo, SIN marca, tamaño ni envase.
   REGLA DE GRANULARIDAD FUNDAMENTAL (NO colapsar tipos a genéricos):
   - Quesos: NUNCA "Queso" a secas. Usá "Queso Cremoso", "Queso Port Salut", "Queso Azul", "Queso Sardo",
     "Queso Muzzarella", "Queso Tybo", "Queso Cheddar", "Queso Danbo", "Queso Untable", "Queso Crema", "Queso Provoleta", etc.
   - Harinas: NUNCA "Harina" a secas. Usá "Harina de Trigo", "Harina de Maíz", "Harina de Almendras", "Harina de Arroz", etc.
   - Semillas: NUNCA "Semillas" a secas. Usá "Semillas de Chía", "Semillas de Girasol", "Semillas de Lino", "Semillas de Sésamo", etc.
   - Milanesas: NUNCA "Milanesa" a secas. Usá "Milanesa de Carne", "Milanesa de Pollo", "Milanesa de Merluza", "Milanesa de Soja", "Milanesa de Cerdo", "Milanesa Vegetal", etc.
   - Medallones: NUNCA "Medallón" a secas. Usá "Medallón de Carne", "Medallón de Pollo", "Medallón de Merluza", "Medallón de Soja", "Medallón Vegetal", etc.
   - Pescados: NUNCA "Filet" a secas. Usá "Filet de Merluza", "Filet de Abadejo", "Filet de Lenguado", "Filet de Salmón", etc.
2. variedad: Atributo distintivo secundario (corte, presentación física, sabor, %graso, tipo de molienda).
   NUNCA repite el producto ni incluye marca/envase/tamaño.
   - Para Quesos: "En Fetas", "En Hebras", "Rallado", "Por Peso", "Horma", "Light", "Sin Lactosa", "Sin Sal", "Clásico".
   - Para Harina de Trigo: "000", "0000", "Leudante", "Integral", "Para Pizza".
   - Para Leche fluida: "Entera", "Descremada", "Deslactosada", "Chocolatada".
   - Para Pescados/Milanesas: "Rebozado", "A la Romana", "Congelado", "Clásico".
   - Si no hay atributo secundario: "Clásico".
3. envase: SOLO uno de {ENVASES_VALIDOS}.
   - Ningún líquido va en "Paquete" (bebidas/aceites/vinagres → Botella salvo lata/cartón/bidón explícito).
   - Ningún artículo que no sea conserva metálica hermética va en "Lata" (abrelatas y utensilios van en "Unidad" o "Blister").
   - Productos unitarios duraderos/bazar/limpieza van en "Unidad" o "Blister".
   - Leche fluida: "Sch", "Sachet", "Sach", "Ultra"/"Ultrapasteurizada" o "Multid." sin "LV/UAT/UHT/Larga Vida" → Sachet;
     "LV", "L/V", "UAT", "UHT", "Larga Vida" → Cartón (Tetra Brik).
4. contenido: número + unidad en (g, kg, ml, litro, u). Usá la descripción y cantidad_sepa:
   "1000 Cm3" → 1 litro; "x 60 Cáps" → 60 u. Nunca "Estándar".
5. marca: marca comercial real. Si dice "Generico" o vacío y la descripción la menciona, extraela ("Leche Tregar" → Tregar).
6. descartar (d=1) si NO es de supermercado: medicamentos éticos con receta bajo receta médica,
   electrodomésticos, tecnología, informática, juguetes/juegos, muebles, ferretería pesada,
   indumentaria/calzado, repuestos/aceites de automotor, plantas/tierra/jardinería, bazar duradero.
   IMPORTANTE - SÍ PERTENECEN A SUPERMERCADO Y NUNCA SE DESCARTAN (d=0):
   - Perfumería, Cuidado Personal y Cosmética (shampoo, jabón, desodorante, tintura, cremas, óleo capilar/restructurante).
   - Bebés y Maternidad: Óleo calcáreo, pañales, toallitas húmedas, mamaderas, chupetes, talco.
   - Primeros auxilios de góndola de supermercado: Algodón hidrófilo, alcohol medicinal/etílico al 70%/96%, gasas, curitas.
   - Limpieza del hogar e insecticidas.

Respondé SOLO JSON, sin markdown. Incluí ÚNICAMENTE las líneas con al menos un error, ordenadas por i ascendente,
con el registro COMPLETO corregido:
{{"r":[{{"i":3,"p":"Leche","v":"Entera","e":"Sachet","c":1,"u":"litro","m":"Coto","d":0,"x":"envase"}}]}}
"x" = campos corregidos o motivo breve. Si todo está bien: {{"r":[]}}"""


# --------------------------------------------------------------------- datos
def limpiar_texto(texto: str) -> str:
    """Quita stopwords, comas vacías y espacios redundantes para ahorrar tokens."""
    t = re.sub(r"[,;]+\s*(?=[,;])", "", str(texto or ""))
    t = re.sub(r"\s*,\s*,\s*", " ", t).replace("|", "/")
    palabras = [w for w in t.split() if w.lower() not in STOPWORDS_ES]
    return " ".join(palabras).strip(" ,")


def fmt_num(valor: Any) -> str:
    try:
        f = float(valor)
    except (TypeError, ValueError):
        return str(valor or "")
    return str(int(f)) if f.is_integer() else f"{f:g}"


def cargar_datos(filtro_producto: str = "") -> pd.DataFrame:
    """Une items + clusters + catálogo en un único DataFrame auditable."""
    items = pd.read_csv(ITEMS_CSV, dtype=str).fillna("")
    clusters = pd.read_csv(CLUSTERS_CSV, dtype=str).fillna("")
    cat = pd.read_csv(CATALOGO_CSV, dtype=str, encoding="utf-8").fillna("")
    cat = cat.drop_duplicates("id_producto")[
        ["id_producto", "productos_descripcion", "productos_marca",
         "productos_cantidad_presentacion", "productos_unidad_medida_presentacion", "off_nombre"]
    ]
    df = items.merge(clusters[["cluster_id", "producto", "variedad", "presentacion", "categoria"]],
                     on="cluster_id", how="left").merge(cat, on="id_producto", how="left").fillna("")
    if filtro_producto:
        df = df[df["producto"].str.contains(filtro_producto, case=False, regex=False)]
    return df.sort_values(["producto", "variedad", "cluster_id"]).reset_index(drop=True)


def construir_linea(i: int, r: pd.Series) -> str:
    desc = r["productos_descripcion"] or r["off_nombre"] or r["cluster_id"].replace("_", " ")
    cant = f"{fmt_num(r['productos_cantidad_presentacion'])}{r['productos_unidad_medida_presentacion']}"
    actual = (f"{r['producto']}|{r['variedad']}|{r['envase'] or r['presentacion']}|"
              f"{fmt_num(r['contenido_neto'])} {r['unidad_referencia']}|{r['marca']}")
    return f"{i}|{limpiar_texto(desc)}|{limpiar_texto(r['productos_marca'])}|{cant} => {actual}"


# ---------------------------------------------------------------- checkpoint
class Checkpoint:
    """Persistencia incremental thread-safe en JSONL."""

    def __init__(self, ruta, reset: bool = False) -> None:
        self.ruta = ruta
        self.lock = threading.Lock()
        self.auditados: set = set()
        self.correcciones: Dict[str, Dict[str, Any]] = {}
        if reset and ruta.exists():
            ruta.unlink()
        if ruta.exists():
            with open(ruta, "r", encoding="utf-8") as f:
                for linea in f:
                    try:
                        reg = json.loads(linea)
                    except json.JSONDecodeError:
                        continue
                    self.auditados.update(reg.get("ids", []))
                    for c in reg.get("correcciones", []):
                        self.correcciones[c["id_producto"]] = c

    def guardar(self, ids: List[str], correcciones: List[Dict[str, Any]], modelo: str) -> None:
        with self.lock:
            self.auditados.update(ids)
            for c in correcciones:
                self.correcciones[c["id_producto"]] = c
            with open(self.ruta, "a", encoding="utf-8") as f:
                f.write(json.dumps({"ts": datetime.now().isoformat(timespec="seconds"),
                                    "modelo": modelo, "ids": ids,
                                    "correcciones": correcciones}, ensure_ascii=False) + "\n")


# ------------------------------------------------------------------ auditoría
def normalizar_respuesta(item: Dict[str, Any], r: pd.Series, modelo: str) -> Dict[str, Any]:
    env = str(item.get("e") or r["envase"]).strip()
    if env.lower().startswith("cart"):
        env = "Cartón (Tetra Brik)"
    uni = str(item.get("u") or r["unidad_referencia"]).strip().lower()
    cont_raw = str(item.get("c") or r["contenido_neto"]).strip().lower().replace(",", ".")
    m_cont = re.match(r"^([\d.]+)\s*([a-z0-9]*)", cont_raw)
    if m_cont:
        cont_val = m_cont.group(1)
        if m_cont.group(2) and not item.get("u"):
            uni = m_cont.group(2)
    else:
        cont_val = r["contenido_neto"]
    return {
        "id_producto": r["id_producto"],
        "descripcion": r["productos_descripcion"],
        "cluster_id_original": r["cluster_id"],
        "producto": str(item.get("p") or r["producto"]).strip(),
        "variedad": str(item.get("v") or r["variedad"] or "Clásico").strip(),
        "envase": env if env in ENVASES_VALIDOS else r["envase"],
        "contenido_neto": fmt_num(cont_val),
        "unidad": UNIDADES.get(uni, uni),
        "marca": str(item.get("m") or r["marca"]).strip(),
        "descartar": str(item.get("d", "0")).strip().lower() in ("1", "true"),
        "motivo": str(item.get("x") or "")[:120],
        "categoria": r["categoria"],
        "modelo": modelo,
    }


def auditar_lote(llm: LLMCascada, lote: pd.DataFrame, worker: str) -> Tuple[List[str], List[Dict], List[str], str]:
    """Audita un lote. Devuelve (ids_auditados, correcciones, ids_pendientes, modelo)."""
    filas = list(lote.itertuples(index=False))
    lineas = [construir_linea(i + 1, lote.iloc[i]) for i in range(len(filas))]
    obj, modelo, truncado = llm.completar(PROMPT_SISTEMA, "\n".join(lineas), worker=worker)

    correcciones, max_i = [], 0
    for item in obj.get("r", []):
        try:
            idx = int(item.get("i"))
        except (TypeError, ValueError):
            continue
        if 1 <= idx <= len(filas):
            max_i = max(max_i, idx)
            correcciones.append(normalizar_respuesta(item, lote.iloc[idx - 1], modelo))

    ids = lote["id_producto"].tolist()
    if truncado:  # lo posterior al último índice rescatado se vuelve a encolar
        return ids[:max_i], correcciones, ids[max_i:], modelo
    return ids, correcciones, [], modelo


def ejecutar_auditoria(args: argparse.Namespace) -> None:
    df = cargar_datos(args.producto)
    ckpt = Checkpoint(CHECKPOINT, reset=args.reset)
    pendientes = df[~df["id_producto"].isin(ckpt.auditados)]
    if args.limite:
        pendientes = pendientes.head(args.limite)

    print("=" * 78)
    print(" AUDITORÍA LLM PRODUCTO POR PRODUCTO (OpenRouter Free ➔ Gemini Flash Lite)")
    print("=" * 78)
    print(f"[*] Total items: {len(df):,} | ya auditados: {len(ckpt.auditados):,} | "
          f"a auditar: {len(pendientes):,} | lote: {args.batch} | workers: {args.workers}")

    ind = IndicadorVivo()
    llm = LLMCascada(OPENROUTER_API_KEY, GEMINI_API_KEY, indicador=ind, max_tokens=args.max_tokens)
    inicio, hechos, total = time.time(), 0, len(pendientes)

    for pasada in range(3):
        if pendientes.empty:
            break
        lotes = [pendientes.iloc[i:i + args.batch] for i in range(0, len(pendientes), args.batch)]
        reencolar: List[str] = []
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futuros = {pool.submit(auditar_lote, llm, lote, f"w{(n % args.workers) + 1}"): lote
                       for n, lote in enumerate(lotes)}
            for fut in as_completed(futuros):
                try:
                    ids, corr, resto, modelo = fut.result()
                    ckpt.guardar(ids, corr, modelo)
                    reencolar.extend(resto)
                    hechos += len(ids)
                except Exception as e:  # noqa: BLE001
                    ind.log(f"[ERROR] lote descartado para reintento: {str(e)[:120]}")
                    reencolar.extend(futuros[fut]["id_producto"].tolist())
                vel = hechos / max(time.time() - inicio, 1) * 60
                ind.resumen = (f"[pasada {pasada + 1}] {hechos:,}/{total:,} "
                               f"corr {len(ckpt.correcciones):,} {vel:,.0f} it/min")
                ind.set("ok", "")
        pendientes = df[df["id_producto"].isin(reencolar)]
        if not pendientes.empty:
            ind.log(f"[*] Reintentando {len(pendientes):,} items truncados/fallidos...")

    print(f"\n[OK] Auditoría finalizada en {(time.time() - inicio) / 60:.1f} min. "
          f"Uso por modelo: {json.dumps(llm.stats)}")
    exportar_reporte(ckpt)


def exportar_reporte(ckpt: Checkpoint) -> None:
    if not ckpt.correcciones:
        print("[OK] Sin correcciones registradas.")
        return
    rep = pd.DataFrame(ckpt.correcciones.values())
    rep.to_csv(REPORTE_CSV, index=False, encoding="utf-8-sig")
    print(f"[OK] {len(rep):,} correcciones ({int(rep['descartar'].sum()):,} descartes) -> {REPORTE_CSV}")


# ------------------------------------------------------------------ aplicar
def slug(texto: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", str(texto).lower()).strip("_")


def aplicar_correcciones() -> None:
    """Reasigna cada EAN corregido a su clúster canónico y purga descartes."""
    ckpt = Checkpoint(CHECKPOINT)
    if not ckpt.correcciones:
        print("[!] No hay correcciones en el checkpoint.")
        return
    sello = datetime.now().strftime("%Y%m%d_%H%M%S")
    for ruta in (CLUSTERS_CSV, ITEMS_CSV):
        shutil.copy2(ruta, ruta.with_suffix(f".{sello}.bak"))

    items = pd.read_csv(ITEMS_CSV, dtype=str).fillna("")
    clusters = pd.read_csv(CLUSTERS_CSV, dtype=str).fillna("")
    existentes = set(clusters["cluster_id"])
    nuevos, descartes, movidos = [], set(), 0

    for c in ckpt.correcciones.values():
        if c["descartar"]:
            descartes.add(c["id_producto"])
            continue
        prod, var, env = c["producto"], c["variedad"] or "Clásico", c["envase"]
        tam = f"{c['contenido_neto']}{c['unidad']}"
        cid = f"{slug(prod)}_{slug(var)}_{slug(env)}_{tam}"
        mask = items["id_producto"] == c["id_producto"]
        if not mask.any():
            continue
        items.loc[mask, ["cluster_id", "marca", "envase", "unidad_referencia", "modelo_ia"]] = [
            cid, c["marca"], env, c["unidad"], f"auditoria_llm:{c['modelo']}"]
        items.loc[mask, "contenido_neto"] = str(float(c["contenido_neto"] or 0) or "")
        movidos += 1
        if cid not in existentes:
            existentes.add(cid)
            generica = var.lower() in ("clásico", "clasico") or var.lower() in prod.lower()
            nuevos.append({"cluster_id": cid, "producto": prod, "variedad": var, "presentacion": env,
                           "nombre_canonico": prod if generica else f"{prod} {var}",
                           "categoria": c.get("categoria") or "Almacén"})

    items = items[~items["id_producto"].isin(descartes)]
    clusters = pd.concat([clusters, pd.DataFrame(nuevos)], ignore_index=True)
    clusters = clusters[clusters["cluster_id"].isin(set(items["cluster_id"]))]
    items.to_csv(ITEMS_CSV, index=False, encoding="utf-8")
    clusters.to_csv(CLUSTERS_CSV, index=False, encoding="utf-8")
    print(f"[OK] Aplicado: {movidos:,} EANs reclasificados, {len(descartes):,} descartados, "
          f"{len(nuevos):,} clústeres nuevos. Backups *.{sello}.bak")
    print("[>] Siguiente paso: python ingesta/5_subir_supabase.py --clusters-only")


def main() -> None:
    p = argparse.ArgumentParser(description="Auditoría LLM de productos y clústeres")
    p.add_argument("--batch", type=int, default=100, help="Productos por llamada LLM (default 100)")
    p.add_argument("--workers", type=int, default=3, help="Lotes en paralelo (default 3)")
    p.add_argument("--max-tokens", type=int, default=5000)
    p.add_argument("--limite", type=int, default=0, help="Auditar solo N items (prueba)")
    p.add_argument("--producto", default="", help="Filtrar por producto (ej. Leche)")
    p.add_argument("--reset", action="store_true", help="Borra el checkpoint y empieza de cero")
    p.add_argument("--reporte", action="store_true", help="Solo exporta el CSV de correcciones")
    p.add_argument("--aplicar", action="store_true", help="Aplica correcciones a los CSV de clústeres")
    args = p.parse_args()

    if args.aplicar:
        aplicar_correcciones()
    elif args.reporte:
        exportar_reporte(Checkpoint(CHECKPOINT))
    else:
        try:
            ejecutar_auditoria(args)
        except KeyboardInterrupt:
            print("\n[!] Interrumpido. El progreso quedó guardado; re-ejecutá para reanudar.")


if __name__ == "__main__":
    main()
