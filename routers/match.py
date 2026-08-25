import asyncio

from fastapi import (
    APIRouter,
    File,
    HTTPException,
    UploadFile,
    status,
)

from core.config import (
    MAX_IMAGE_SIZE_BYTES,
    MODEL_NAME,
)

from models.embedding import (
    EmbeddingResponse,
)

from services.dinov2_service import (
    get_dinov2_service,
)


router = APIRouter(
    prefix="/api/match",
    tags=["match"],
)


@router.post(
    "/embed",
    response_model=EmbeddingResponse,
)
async def embed_image(
    image: UploadFile = File(...),
) -> EmbeddingResponse:
    """
    Receive an image from Flutter and return a
    normalized 768-dimensional DINOv2 embedding.
    """

    # ---------------------------------------------------------
    # Read at most 10 MB + 1 byte.
    #
    # Reading one extra byte allows us to determine whether
    # the file exceeds our limit without loading an
    # arbitrarily large upload into memory.
    # ---------------------------------------------------------

    try:
        image_bytes = await image.read(
            MAX_IMAGE_SIZE_BYTES + 1
        )
    finally:
        await image.close()

    # ---------------------------------------------------------
    # Empty file
    # ---------------------------------------------------------

    if not image_bytes:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=(
                "Uploaded image is empty."
            ),
        )

    # ---------------------------------------------------------
    # Maximum upload size
    # ---------------------------------------------------------

    if (
        len(image_bytes)
        > MAX_IMAGE_SIZE_BYTES
    ):
        raise HTTPException(
            status_code=413,
            detail=(
                "Image must be "
                "10 MB or smaller."
            ),
        )

    # ---------------------------------------------------------
    # Generate DINOv2 embedding
    # ---------------------------------------------------------

    try:
        service = get_dinov2_service()

        # Model inference is CPU/GPU-bound rather than
        # asynchronous I/O.
        #
        # to_thread prevents inference from blocking
        # FastAPI's event loop.
        embedding = await asyncio.to_thread(
            service.embed_image_bytes,
            image_bytes,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=str(exc),
        ) from exc

    except Exception as exc:
        raise HTTPException(
            status_code=(
                status
                .HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "DINOv2 inference failed: "
                f"{exc}"
            ),
        ) from exc

    # ---------------------------------------------------------
    # Response
    # ---------------------------------------------------------

    return EmbeddingResponse(
        model=MODEL_NAME,
        dimension=len(embedding),
        embedding=embedding,
    )