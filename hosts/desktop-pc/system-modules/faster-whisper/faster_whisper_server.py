import asyncio
import gc
import logging
import os
import struct
import time
import wave
from contextlib import asynccontextmanager
from tempfile import NamedTemporaryFile

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from faster_whisper import WhisperModel
import httpx
import uvicorn


MODEL_NAME = os.getenv("FASTER_WHISPER_MODEL", "small")
DEVICE = os.getenv("FASTER_WHISPER_DEVICE", "auto")
COMPUTE_TYPE = os.getenv("FASTER_WHISPER_COMPUTE_TYPE", "int8")
BEAM_SIZE = int(os.getenv("FASTER_WHISPER_BEAM_SIZE", "5"))
BEST_OF = int(os.getenv("FASTER_WHISPER_BEST_OF", "5"))
VAD_FILTER = os.getenv("FASTER_WHISPER_VAD_FILTER", "true").strip().lower() in {"1", "true", "yes", "on"}
TEMPERATURE = float(os.getenv("FASTER_WHISPER_TEMPERATURE", "0"))
HOST = os.getenv("FASTER_WHISPER_HOST", "127.0.0.1")
PORT = int(os.getenv("FASTER_WHISPER_PORT", "8000"))
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://host.docker.internal:11434/api/generate")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:3b")
IDLE_UNLOAD_SECONDS = int(os.getenv("FASTER_WHISPER_IDLE_UNLOAD_SECONDS", "300"))

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("whisper")

model = None
http_client: httpx.AsyncClient | None = None
unload_task: asyncio.Task | None = None
load_lock = asyncio.Lock()


def unload_model():
    global model
    if model is None:
        return
    log.info("unloading model from GPU...")
    t0 = time.time()
    del model
    model = None
    gc.collect()
    try:
        import torch
        torch.cuda.empty_cache()
    except ImportError:
        pass
    log.info("model unloaded in %.1fs", time.time() - t0)


async def schedule_unload(delay: int):
    global unload_task
    if unload_task is not None:
        unload_task.cancel()
        try:
            await unload_task
        except asyncio.CancelledError:
            pass
    unload_task = asyncio.create_task(_delayed_unload(delay))


async def _delayed_unload(delay: int):
    try:
        await asyncio.sleep(delay)
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, unload_model)
    except asyncio.CancelledError:
        pass


async def load_model():
    global model
    if model is not None:
        return
    async with load_lock:
        if model is not None:
            return
        log.info("loading model %s on %s (%s)", MODEL_NAME, DEVICE, COMPUTE_TYPE)
        t0 = time.time()
        loop = asyncio.get_running_loop()
        model = await loop.run_in_executor(
            None, lambda: WhisperModel(MODEL_NAME, device=DEVICE, compute_type=COMPUTE_TYPE)
        )
        log.info("model loaded in %.1fs", time.time() - t0)

        log.info("running warmup inference...")
        t0 = time.time()
        sr = 16000
        with NamedTemporaryFile(suffix=".wav", delete=False) as f:
            with wave.open(f, "w") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(sr)
                for _ in range(sr // 2):
                    w.writeframes(struct.pack("<h", 0))
            tmp = f.name
        try:
            await loop.run_in_executor(
                None, lambda: model.transcribe(tmp, beam_size=1, best_of=1, language="ru")
            )
        except Exception as e:
            log.warning("warmup failed: %s", e)
        finally:
            os.unlink(tmp)
        log.info("warmup done in %.1fs", time.time() - t0)


@asynccontextmanager
async def lifespan(app: FastAPI):
    global http_client
    http_client = httpx.AsyncClient(timeout=60.0)
    yield
    if unload_task is not None:
        unload_task.cancel()
        try:
            await unload_task
        except asyncio.CancelledError:
            pass
    unload_model()
    await http_client.aclose()
    http_client = None


app = FastAPI(lifespan=lifespan)


async def transcribe_audio(content: bytes, filename: str | None, language: str | None) -> str:
    await load_model()

    suffix = os.path.splitext(filename or "voice.ogg")[1] or ".ogg"
    with NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(content)
        tmp_path = tmp.name

    try:
        loop = asyncio.get_running_loop()
        segments, _ = await loop.run_in_executor(
            None,
            lambda: model.transcribe(
                tmp_path,
                language=language or None,
                beam_size=BEAM_SIZE,
                best_of=BEST_OF,
                vad_filter=VAD_FILTER,
                temperature=TEMPERATURE,
                condition_on_previous_text=True,
            ),
        )
        text = " ".join(segment.text.strip() for segment in segments).strip()
        if not text:
            raise HTTPException(status_code=422, detail="empty transcript")
        return text
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        os.unlink(tmp_path)
        if IDLE_UNLOAD_SECONDS > 0:
            await schedule_unload(IDLE_UNLOAD_SECONDS)


@app.post("/transcribe")
async def transcribe(
    file: UploadFile = File(...),
    language: str | None = Form(default=None),
    model_name: str | None = Form(default=None),
):
    del model_name
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="empty file")
    text = await transcribe_audio(content, file.filename, language)
    return {"text": text}


@app.post("/transcribe/better")
async def transcribe_better(
    file: UploadFile = File(...),
    language: str | None = Form(default=None),
    model_name: str | None = Form(default=None),
):
    del model_name
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="empty file")
    text = await transcribe_audio(content, file.filename, language)
    corrected = await correct_text(text)
    return {"text": corrected}


async def correct_text(text: str) -> str:
    prompt = (
        "Исправь только орфографические ошибки и пунктуацию. "
        "Не меняй содержание, стиль, порядок слов. "
        "Верни только исправленный текст без пояснений.\n\n"
        f"{text}"
    )
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0},
    }
    log.info("sending to ollama (%s) for correction...", OLLAMA_MODEL)
    t0 = time.time()
    resp = await http_client.post(OLLAMA_URL, json=payload)
    resp.raise_for_status()
    data = resp.json()
    corrected = data.get("response", "").strip()
    log.info("ollama correction done in %.1fs", time.time() - t0)
    return corrected or text


if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT)
