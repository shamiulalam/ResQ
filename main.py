from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.config import (
    EXPECTED_EMBEDDING_DIMENSION,
    MODEL_NAME,
)
from routers.match import router as match_router
from services.dinov2_service import get_dinov2_service
from routers.auth_bridge import (
    router as auth_bridge_router,
)
from routers.chat import router as chat_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[ResQ] Starting AI backend...")

    # Load the DINOv2 model once at startup
    service = get_dinov2_service()
    app.state.dinov2 = service

    print("[ResQ] AI backend ready.")

    yield

    print("[ResQ] AI backend shutting down.")


# IMPORTANT:
# This must exist at module level for "main:app"
app = FastAPI(
    title="ResQ AI Backend",
    description=(
        "DINOv2 image embedding backend "
        "for ResQ pet re-identification."
    ),
    version="1.0.0",
    lifespan=lifespan,
)


# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# Routers
app.include_router(match_router)
app.include_router(auth_bridge_router)
app.include_router(chat_router)


@app.get("/")
def root():
    return {
        "message": "ResQ AI Backend is running",
        "model": MODEL_NAME,
    }


@app.get("/health")
def health():
    service = get_dinov2_service()

    return {
        "status": "ok",
        "model": MODEL_NAME,
        "embedding_dimension": EXPECTED_EMBEDDING_DIMENSION,
        "device": str(service.device),
    }
