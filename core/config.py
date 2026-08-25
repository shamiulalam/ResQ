import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

MODEL_NAME = "facebook/dinov2-base"

EXPECTED_EMBEDDING_DIMENSION = 768

MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024

CHAT_MEDIA_BUCKET = os.getenv("SUPABASE_CHAT_MEDIA_BUCKET", "chat-media")
CHAT_MEDIA_MAX_SIZE_BYTES = int(
    os.getenv("CHAT_MEDIA_MAX_SIZE_BYTES", str(25 * 1024 * 1024))
)
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

FIREBASE_SERVICE_ACCOUNT_PATH = Path(
    os.getenv(
        "FIREBASE_SERVICE_ACCOUNT_PATH",
        str(
            BASE_DIR /
            "firebase-service-account.json"
        ),
    )
)
