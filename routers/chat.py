from pathlib import PurePosixPath
from mimetypes import guess_type

from fastapi import APIRouter, File, Form, Header, HTTPException, UploadFile
from starlette.concurrency import run_in_threadpool

from core.config import CHAT_MEDIA_MAX_SIZE_BYTES
from routers.auth_bridge import get_firebase_auth_service
from services.chat_service import get_chat_backend_service

router = APIRouter(prefix="/api/chat", tags=["chat"])


def authenticated_uid(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Bearer token is required.")
    try:
        return get_firebase_auth_service().verify_id_token(
            authorization.removeprefix("Bearer ").strip()
        )
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid Firebase token.") from exc


def translate_error(exc: Exception) -> HTTPException:
    if isinstance(exc, PermissionError):
        return HTTPException(status_code=403, detail=str(exc))
    if isinstance(exc, LookupError):
        return HTTPException(status_code=404, detail=str(exc))
    return HTTPException(status_code=503, detail=str(exc))


@router.get("/users")
async def list_chat_users(
    authorization: str | None = Header(default=None),
):
    uid = authenticated_uid(authorization)
    users = await run_in_threadpool(
        get_chat_backend_service().list_chat_users,
        uid,
    )
    return {"users": users}


@router.post("/media/upload")
async def upload_chat_media(
    conversation_id: str = Form(...),
    message_id: str = Form(...),
    file: UploadFile = File(...),
    authorization: str | None = Header(default=None),
):
    uid = authenticated_uid(authorization)
    content = await file.read(CHAT_MEDIA_MAX_SIZE_BYTES + 1)
    if len(content) > CHAT_MEDIA_MAX_SIZE_BYTES:
        raise HTTPException(status_code=413, detail="File exceeds chat upload limit.")
    guessed_type, _ = guess_type(file.filename or "")
    content_type = file.content_type or guessed_type or "application/octet-stream"
    if content_type == "application/octet-stream" and guessed_type:
        content_type = guessed_type
    allowed = (
        content_type.startswith("image/")
        or content_type.startswith("video/")
        or content_type in {"application/pdf", "text/plain"}
    )
    if not allowed:
        raise HTTPException(status_code=415, detail="Unsupported chat file type.")
    try:
        object_path = await run_in_threadpool(
            get_chat_backend_service().upload_media,
            uid=uid,
            conversation_id=conversation_id,
            message_id=message_id,
            filename=PurePosixPath(file.filename or "attachment").name,
            content_type=content_type,
            content=content,
        )
    except Exception as exc:
        raise translate_error(exc) from exc
    return {"objectPath": object_path}


@router.get("/media/signed-url")
async def get_chat_media_url(
    conversation_id: str,
    object_path: str,
    authorization: str | None = Header(default=None),
):
    uid = authenticated_uid(authorization)
    try:
        signed_url = await run_in_threadpool(
            get_chat_backend_service().signed_url,
            uid=uid,
            conversation_id=conversation_id,
            object_path=object_path,
        )
    except Exception as exc:
        raise translate_error(exc) from exc
    return {"signedUrl": signed_url, "expiresIn": 300}


@router.post("/notifications/send")
async def send_chat_notification(
    payload: dict,
    authorization: str | None = Header(default=None),
):
    uid = authenticated_uid(authorization)
    try:
        sent = await run_in_threadpool(
            get_chat_backend_service().notify_message,
            uid=uid,
            conversation_id=str(payload.get("conversationId", "")),
            message_id=str(payload.get("messageId", "")),
        )
    except Exception as exc:
        raise translate_error(exc) from exc
    return {"sent": sent}
