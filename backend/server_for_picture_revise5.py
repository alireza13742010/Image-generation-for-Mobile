"""
DEBUG VERSION — synchronous, single file, verbose logging.

No job_id, no background thread, no /status polling. /generate just
blocks until the image is ready and prints each step to the terminal
on laptop B so you can see exactly where it's stuck (if it's stuck).

Run with:
  uvicorn server_debug:app --host 0.0.0.0 --port 8000

Then in a separate terminal:
  ngrok http --url=venue-lubricant-cruelly.ngrok-free.dev 8000
"""

import os

import torch
from diffusers import ZImagePipeline
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class GenerateRequest(BaseModel):
    prompt: str


print("[startup] loading model, this can take a while...")
pipeline = ZImagePipeline.from_pretrained(
    "./Z-Image",
    torch_dtype=torch.bfloat16,
    low_cpu_mem_usage=False,
)
pipeline.to("cuda")
print("[startup] model loaded and on GPU. Server is ready.")


@app.post("/generate")
def generate(req: GenerateRequest):
    print(f"[1] received prompt: {req.prompt!r}")

    print("[2] generating image (this request will stay open until it's done)...")
    image = pipeline(
        prompt=req.prompt,
        num_inference_steps=50,
        guidance_scale=7.0,
    ).images[0]
    print("[3] generation finished")

    if image.mode != "RGB":
        image = image.convert("RGB")

    image.save("output.jpg", format="JPEG", quality=95)
    print("[4] saved output.jpg")

    return {"status": "done"}


@app.get("/image")
def image():
    if not os.path.exists("output.jpg"):
        print("[image] requested but output.jpg does not exist yet")
        return {"status": "error", "detail": "no image yet"}
    print("[5] serving output.jpg")
    return FileResponse("output.jpg", media_type="image/jpeg")
