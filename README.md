# Z-Image — Text-to-Image Generation App

A Flutter mobile app paired with a FastAPI backend for on-demand AI image generation. Users type a prompt, the app sends it to a self-hosted GPU server running a diffusion pipeline, and the generated image is displayed and saved to a persistent local history.

## Features

- **Prompt-to-image generation** — simple text field, tap Generate, wait for the result. The request blocks until the image is ready (no polling required).
- **Persistent history** — every generated image is saved to the device's app-documents directory along with its prompt and generation settings, so it survives app restarts and updates. Browse past generations in a grid, tap through to a full-screen view.
- **Account management** — sign-in via Firebase Auth, with sign-out and account deletion built into the account menu.
- **Settings panel** — a resolution / inference-steps / guidance-scale / seed control surface, scaffolded for future wiring into the generation request.
- **Self-hosted backend** — a lightweight FastAPI server wraps a diffusers `ZImagePipeline`, runs inference on a local GPU, and exposes the result over a simple two-endpoint HTTP API (generate, then fetch).

## Architecture

```
┌─────────────────┐         HTTPS (via ngrok tunnel)         ┌──────────────────────┐
│   Flutter App    │ ───────────────────────────────────────▶│   FastAPI Server     │
│                  │  POST /generate {prompt}                │   (GPU machine)      │
│  • Generate tab  │◀─────────────────────────────────────── │                      │
│  • History tab   │  {"status": "done"}                     │  ZImagePipeline      │
│  • Auth / account│                                         │  (diffusers, bf16,   │
│                  │  GET /image                             │   CUDA)              │
│                  │◀─────────────────────────────────────── │                      │
└─────────────────┘  image/jpeg bytes                        └──────────────────────┘
        │
        ▼
  Local history store
  (app documents dir,
   JSON index + PNGs)
```

The current server implementation (`server_for_picture_revise5.py`) is intentionally synchronous and single-file for easy debugging: no job IDs, no background workers, no `/status` endpoint — `/generate` simply blocks until the image is written to disk, and verbose `print()` statements mark each step so issues are easy to trace from the terminal on the GPU machine.

## Tech Stack

**Frontend**
- Flutter (Material 3, dark theme)
- `http` for API calls
- `path_provider` for on-device file storage
- Firebase Auth for sign-in / account lifecycle

**Backend**
- FastAPI + Uvicorn
- [🤗 diffusers](https://github.com/huggingface/diffusers) `ZImagePipeline`
- PyTorch (bfloat16 inference on CUDA)
- ngrok for exposing the local server over HTTPS during development

## Project Structure

| File | Purpose |
|---|---|
| `main.dart` | App entry point, Firebase init, root `MaterialApp` |
| `root_page.dart` | Bottom-nav shell (Generate / History), account menu, generate flow |
| `models.dart` | Shared enums and data models (`SeedMode`, `LoadState`, pipeline settings) |
| `history_store.dart` | Reads/writes generation history to on-device storage |
| `history_page.dart` | Grid view + full-screen viewer for past generations |
| `history_entry.dart` | Serializable model for a single history record |
| `server_for_picture_revise5.py` | FastAPI backend wrapping the diffusion pipeline |

## Getting Started

### Backend

```bash
# from the machine with a CUDA GPU and the Z-Image weights in ./Z-Image
pip install fastapi uvicorn diffusers torch
uvicorn server_for_picture_revise5:app --host 0.0.0.0 --port 8000
```

Expose it publicly for the app to reach (development):
```bash
ngrok http --url=<your-ngrok-domain> 8000
```
Update `kServerUrl` in `root_page.dart` to match.

### Frontend

```bash
flutter pub get
flutter run
```

Requires Firebase configuration (`firebase_options.dart`, generated via `flutterfire configure`) for the auth flow to work.

## Known Limitations

- The Settings dialog is currently **display-only** — its values are not yet sent to the generation request; the server uses hardcoded inference steps (50) and guidance scale (7.0).
- The backend handles one request at a time (fully synchronous) — not suited for concurrent users without further work (job queue, polling, or websockets).
- `output.jpg` is overwritten on every generation server-side; there's no per-request file naming on the backend (history/versioning is handled entirely client-side).
## Demo
https://github.com/user-attachments/assets/504ff730-40ef-4874-8181-50a24c721c84
<img width="360" height="800" alt="8a250601-8784-4fb9-a2fb-ce8c64070e47" src="https://github.com/user-attachments/assets/6cbd2ea5-113e-4098-b981-42c24985ef08" />
<img width="576" height="1280" alt="photo_6032677645281070868_y" src="https://github.com/user-attachments/assets/86a05ed2-693b-41da-bcfc-348313d4ff7e" />
<img width="576" height="1280" alt="photo_6032677645281070869_y" src="https://github.com/user-attachments/assets/38502c87-2957-46a6-b859-f158a23b8106" />


## License

you should contatc us at:alirezatavakolianart@gmail.com
