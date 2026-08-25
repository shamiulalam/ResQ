from functools import lru_cache

from fastapi import (
    APIRouter,
    Header,
    HTTPException,
    status,
)
from starlette.concurrency import run_in_threadpool

from services.firebase_auth_service import (
    FirebaseAuthService,
)


router = APIRouter(
    prefix="/api/auth",
    tags=["auth"],
)


@lru_cache(maxsize=1)
def get_firebase_auth_service() -> FirebaseAuthService:
    """Create the bridge lazily so unrelated API routes can still start."""
    return FirebaseAuthService()


@router.post(
    "/sync-supabase-role"
)
async def sync_supabase_role(
    authorization: str | None = Header(
        default=None
    ),
):
    """
    Verify the current Firebase user and ensure
    their Firebase ID token can receive the
    Supabase Postgres role:

        role = authenticated
    """

    if authorization is None:
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail=(
                "Authorization header is missing."
            ),
        )

    prefix = "Bearer "

    if not authorization.startswith(
        prefix
    ):
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail=(
                "Authorization header must use "
                "Bearer authentication."
            ),
        )

    id_token = authorization[
        len(prefix):
    ].strip()

    if not id_token:
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail="Firebase token is missing.",
        )

    try:
        uid, changed = await run_in_threadpool(
            get_firebase_auth_service()
            .ensure_supabase_role,
            id_token,
        )

    except Exception as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail=(
                "Invalid Firebase "
                "authentication token."
            ),
        ) from exc

    return {
        "success": True,
        "uid": uid,
        "role": "authenticated",
        "claim_changed": changed,
    }
