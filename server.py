import os
import base64

from fastapi import FastAPI, UploadFile, File
from llama_cpp import Llama

# 1) Параметры через окружение
MODEL_PATH = os.getenv("MODEL_PATH", "/models/llava-v1.6-mistral-7b.Q6_K.gguf")
CHAT_FORMAT = "llava-1-6"
N_GPU_LAYERS = int(os.getenv("GPU_LAYERS", "16"))
F16_KV = True

# 2) Инициализация модели
llm = Llama(
    model_path=MODEL_PATH,
    chat_format=CHAT_FORMAT,
    n_gpu_layers=N_GPU_LAYERS,
    f16_kv=F16_KV,
)

app = FastAPI(title="Vision Captioning Service")

# 3) Health-check
@app.get("/")
def health():
    return {"message": "🚀 Vision model loaded and ready!"}

# 4) Эндпоинт для captioning
@app.post("/vision/caption")
async def caption(file: UploadFile = File(...)):
    """
    Принимаем картинку, кодируем её в base64,
    подсовываем LLaVA-промпт и возвращаем текст.
    """
    # читаем байты картинки
    data = await file.read()
    # base64
    b64 = base64.b64encode(data).decode("utf-8")
    # формируем prompt для LLaVA
    prompt = f"<img>{b64}</img>\nDescribe the image in one sentence:"
    # вызываем модель
    resp = llm(prompt=prompt, max_tokens=128, temperature=0.2)
    text = resp["choices"][0]["text"].strip()
    return {"caption": text}
