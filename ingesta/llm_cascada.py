#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Cliente LLM en cascada de 2 niveles con costo $0.00 y alta resiliencia.

Nivel 1: OpenRouter (solo endpoints oficiales ':free').
    - Balanceo round-robin modelo por modelo entre lotes.
    - reasoning deshabilitado, max_tokens=5000, streaming con indicador vivo (\\r).
    - Cooldown automático del modelo que responde HTTP 429.
    - Auto-reparación de JSON truncado (cierra el array con ']}').
Nivel 2: Google Gemini (gemini-3.1-flash-lite / preview) como fallback.
    - responseMimeType=application/json y thinkingBudget=0.
    - Backoff exponencial (5s, 10s, 20s...) ante saturación HTTP 429.
"""

import json
import re
import sys
import threading
import time
from typing import Any, Dict, List, Optional, Tuple

import requests

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

OPENROUTER_FREE_MODELS = [
    "nvidia/nemotron-3-super-120b-a12b:free",
    "dots-studio/dots-3-note-preview:free",
    "nvidia/nemotron-3.5-lightning:free",
    "nvidia/nemotron-3.5-super-vl:free",
    "poolside/laguna-s-2.1:free",
]

GEMINI_FALLBACK_MODELS = [
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-2.5-flash-lite",
    "gemini-flash-lite-latest",
    "gemini-3.1-flash-lite-preview",
]


class IndicadorVivo:
    """Indicador de progreso en un único renglón de terminal (thread-safe)."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._estados: Dict[str, str] = {}
        self.resumen = ""

    def set(self, worker: str, texto: str) -> None:
        with self._lock:
            self._estados[worker] = texto
            self._render()

    def clear(self, worker: str) -> None:
        with self._lock:
            self._estados.pop(worker, None)
            self._render()

    def log(self, mensaje: str) -> None:
        """Imprime un mensaje permanente sin romper el renglón vivo."""
        with self._lock:
            sys.stdout.write("\r" + " " * 150 + "\r" + mensaje + "\n")
            self._render()

    def _render(self) -> None:
        partes = [self.resumen] + [f"{k}:{v}" for k, v in sorted(self._estados.items())]
        linea = " | ".join(p for p in partes if p)[:148]
        sys.stdout.write("\r" + linea.ljust(148))
        sys.stdout.flush()


def reparar_json(texto: str, clave: str = "r") -> Tuple[Optional[Dict[str, Any]], bool]:
    """Parsea JSON del modelo; si viene truncado reconstruye el array.

    Devuelve (objeto, fue_reparado). Si no se puede rescatar nada, (None, False).
    """
    if not texto:
        return None, False
    limpio = re.sub(r"^```(?:json)?|```$", "", texto.strip(), flags=re.MULTILINE).strip()
    inicio = limpio.find("{")
    inicio_arr = limpio.find("[")
    if inicio_arr != -1 and (inicio == -1 or inicio_arr < inicio):
        limpio = "{\"" + clave + "\":" + limpio[inicio_arr:]
    elif inicio > 0:
        limpio = limpio[inicio:]

    try:
        obj = json.loads(limpio)
        if isinstance(obj, dict) and isinstance(obj.get(clave), list):
            return obj, False
    except json.JSONDecodeError:
        pass

    # Reparación: cortar en el último objeto completo y cerrar ']}'
    posiciones = [m.start() for m in re.finditer(r"\}", limpio)]
    for pos in reversed(posiciones[-400:]):
        candidato = limpio[: pos + 1]
        for cierre in ("]}", "}]}", "]"):
            try:
                obj = json.loads(candidato + cierre)
                if isinstance(obj, dict) and isinstance(obj.get(clave), list):
                    return obj, True
            except json.JSONDecodeError:
                continue
    # Arreglo vacío abierto: {"r":[
    if re.search(r'"' + clave + r'"\s*:\s*\[\s*$', limpio):
        return {clave: []}, True
    return None, False


class LLMCascada:
    """Cascada OpenRouter Free ➔ Gemini Flash Lite con round-robin y backoff."""

    def __init__(
        self,
        openrouter_key: str,
        gemini_key: str,
        indicador: Optional[IndicadorVivo] = None,
        or_models: Optional[List[str]] = None,
        gemini_models: Optional[List[str]] = None,
        max_tokens: int = 5000,
        timeout: int = 180,
    ) -> None:
        self.or_key = openrouter_key
        self.gem_key = gemini_key
        self.or_models = list(or_models or OPENROUTER_FREE_MODELS)
        self.gem_models = list(gemini_models or GEMINI_FALLBACK_MODELS)
        self.max_tokens = max_tokens
        self.timeout = timeout
        self.ind = indicador or IndicadorVivo()
        self._rr = 0
        self._lock = threading.Lock()
        self._cooldown: Dict[str, float] = {}
        self._or_bloqueado_hasta = 0.0
        self.stats: Dict[str, int] = {}

    # ------------------------------------------------------------------ utils
    def _orden_round_robin(self) -> List[str]:
        """Devuelve los modelos OpenRouter rotados a partir del siguiente turno."""
        with self._lock:
            inicio = self._rr % len(self.or_models)
            self._rr += 1
        rotados = self.or_models[inicio:] + self.or_models[:inicio]
        ahora = time.time()
        disponibles = [m for m in rotados if self._cooldown.get(m, 0) <= ahora]
        return disponibles

    def _enfriar(self, modelo: str, segundos: float) -> None:
        with self._lock:
            self._cooldown[modelo] = time.time() + segundos

    def _contar(self, modelo: str) -> None:
        with self._lock:
            self.stats[modelo] = self.stats.get(modelo, 0) + 1

    # ------------------------------------------------------------- openrouter
    def _llamar_openrouter(self, modelo: str, system: str, user: str, worker: str) -> Tuple[str, bool]:
        """Llama a OpenRouter en streaming. Devuelve (texto, truncado_por_longitud)."""
        headers = {
            "Authorization": f"Bearer {self.or_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://compramas.app",
            "X-Title": "CompraMas Auditoria",
        }
        payload = {
            "model": modelo,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "temperature": 0.1,
            "max_tokens": self.max_tokens,
            "reasoning": {"enabled": False},
            "stream": True,
        }
        corto = modelo.split("/")[-1][:22]
        partes: List[str] = []
        truncado = False
        cortado_red = False
        with requests.post(OPENROUTER_URL, headers=headers, json=payload,
                           stream=True, timeout=self.timeout) as resp:
            if resp.status_code == 429:
                raise RateLimitError(f"429 {modelo} {resp.text[:300]}")
            if resp.status_code != 200:
                raise RuntimeError(f"HTTP {resp.status_code}: {resp.text[:200]}")
            try:
                for raw in resp.iter_lines(decode_unicode=True):
                    if not raw or not raw.startswith("data:"):
                        continue
                    dato = raw[5:].strip()
                    if dato == "[DONE]":
                        break
                    try:
                        evento = json.loads(dato)
                    except json.JSONDecodeError:
                        continue
                    if "error" in evento:
                        msg = str(evento["error"])[:200]
                        if "429" in msg or "rate" in msg.lower():
                            raise RateLimitError(msg)
                        raise RuntimeError(msg)
                    choice = (evento.get("choices") or [{}])[0]
                    delta = (choice.get("delta") or {}).get("content") or ""
                    if delta:
                        partes.append(delta)
                        total = sum(len(p) for p in partes)
                        self.ind.set(worker, f"{corto} {total / 1000:.1f}k")
                    if choice.get("finish_reason") == "length":
                        truncado = True
            except (requests.exceptions.ChunkedEncodingError,
                    requests.exceptions.ConnectionError,
                    requests.exceptions.ReadTimeout):
                cortado_red = True  # microcorte: se intenta rescatar lo recibido
        return "".join(partes), (truncado or cortado_red)

    # ----------------------------------------------------------------- gemini
    def _llamar_gemini(self, modelo: str, system: str, user: str, con_thinking_cfg: bool = True) -> Tuple[str, bool]:
        gen_cfg: Dict[str, Any] = {
            "responseMimeType": "application/json",
            "temperature": 0.1,
            "maxOutputTokens": 8192,
        }
        if con_thinking_cfg and "3.5" not in modelo:
            gen_cfg["thinkingConfig"] = {"thinkingBudget": 0}
        body = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": user}]}],
            "generationConfig": gen_cfg,
        }
        resp = requests.post(GEMINI_URL.format(model=modelo), params={"key": self.gem_key},
                             json=body, timeout=self.timeout)
        if resp.status_code == 429:
            raise RateLimitError(f"429 {modelo}")
        if resp.status_code in (503, 500, 502, 504):
            raise TransientServerError(f"{resp.status_code} {modelo}: {resp.text[:120]}")
        if resp.status_code == 400 and con_thinking_cfg and "thinking" in resp.text.lower():
            return self._llamar_gemini(modelo, system, user, con_thinking_cfg=False)
        if resp.status_code != 200:
            raise RuntimeError(f"HTTP {resp.status_code}: {resp.text[:200]}")
        data = resp.json()
        cand = (data.get("candidates") or [{}])[0]
        texto = "".join(p.get("text", "") for p in (cand.get("content") or {}).get("parts", []))
        return texto, cand.get("finishReason") == "MAX_TOKENS"

    # ----------------------------------------------------------------- public
    def completar(self, system: str, user: str, worker: str = "w1",
                  clave: str = "r") -> Tuple[Dict[str, Any], str, bool]:
        """Ejecuta la cascada completa. Devuelve (json, modelo, truncado)."""
        if self.or_key and time.time() >= self._or_bloqueado_hasta:
            for modelo in self._orden_round_robin():
                try:
                    texto, truncado = self._llamar_openrouter(modelo, system, user, worker)
                    obj, reparado = reparar_json(texto, clave)
                    if obj is not None:
                        self._contar(modelo)
                        return obj, modelo, (truncado or reparado)
                    self.ind.log(f"    [~] {modelo}: JSON inválido, probando siguiente modelo...")
                except RateLimitError as e:
                    if "per-day" in str(e) or "per_day" in str(e):
                        with self._lock:
                            self._or_bloqueado_hasta = time.time() + 3600
                        self.ind.log("    [429] OpenRouter: cuota DIARIA free agotada -> nivel 1 en pausa 1h, usando Gemini")
                        break
                    self._enfriar(modelo, 60)
                    self.ind.log(f"    [429] {modelo} saturado -> cooldown 60s")
                except Exception as e:  # noqa: BLE001 - se registra y se cae al siguiente
                    self._enfriar(modelo, 20)
                    self.ind.log(f"    [!] {modelo}: {str(e)[:110]}")

        if not self.gem_key:
            raise RuntimeError("Todos los modelos OpenRouter fallaron y no hay GEMINI_API_KEY.")

        espera = 5
        for intento in range(6):
            for modelo in self.gem_models:
                self.ind.set(worker, f"gemini:{modelo[-12:]} intento {intento + 1}")
                try:
                    texto, truncado = self._llamar_gemini(modelo, system, user)
                    obj, reparado = reparar_json(texto, clave)
                    if obj is not None:
                        self._contar(modelo)
                        return obj, modelo, (truncado or reparado)
                except (RateLimitError, TransientServerError) as e:
                    self.ind.log(f"    [~] {modelo}: {str(e)[:70]} -> probando siguiente Gemini...")
                    continue
                except Exception as e:  # noqa: BLE001
                    self.ind.log(f"    [!] {modelo}: {str(e)[:110]}")
            self.ind.set(worker, f"backoff {espera}s")
            time.sleep(espera)
            espera = min(espera * 2, 80)
        raise RuntimeError("Cascada agotada: OpenRouter y Gemini no respondieron.")


class RateLimitError(Exception):
    """Señal de saturación (HTTP 429) para activar cooldown o backoff."""


class TransientServerError(Exception):
    """Error transitorio de servidor (503 High Demand, 500, 502, 504)."""
