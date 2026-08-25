from functools import lru_cache
from io import BytesIO
from threading import Lock

import torch
import torch.nn.functional as F
from PIL import Image, UnidentifiedImageError
from transformers import AutoImageProcessor, AutoModel

from core.config import (
    EXPECTED_EMBEDDING_DIMENSION,
    MODEL_NAME,
)


class DinoV2Service:
    """
    Loads facebook/dinov2-base and generates normalized
    768-dimensional image embeddings.

    The model is loaded once and reused for all requests.
    """

    def __init__(self) -> None:
        # -----------------------------------------------------
        # Select device
        # -----------------------------------------------------

        self.device = torch.device(
            "cuda"
            if torch.cuda.is_available()
            else "cpu"
        )

        print(
            f"[DINOv2] Loading {MODEL_NAME} "
            f"on {self.device}..."
        )

        # -----------------------------------------------------
        # Load image processor
        # -----------------------------------------------------

        self.processor = (
            AutoImageProcessor.from_pretrained(
                MODEL_NAME
            )
        )

        # -----------------------------------------------------
        # Load pretrained model
        # -----------------------------------------------------

        self.model = AutoModel.from_pretrained(
            MODEL_NAME
        )

        self.model.to(self.device)

        # Inference mode.
        # We are not training the model here.
        self.model.eval()

        # Protect inference when multiple HTTP requests
        # arrive at the same time.
        self._inference_lock = Lock()

        # -----------------------------------------------------
        # Validate model dimensions
        # -----------------------------------------------------

        hidden_size = int(
            self.model.config.hidden_size
        )

        if (
            hidden_size
            != EXPECTED_EMBEDDING_DIMENSION
        ):
            raise RuntimeError(
                "Unexpected DINOv2 hidden size: "
                f"{hidden_size}. Expected "
                f"{EXPECTED_EMBEDDING_DIMENSION}."
            )

        print(
            "[DINOv2] Model loaded successfully. "
            f"Embedding dimension: {hidden_size}"
        )

    def embed_image_bytes(
        self,
        image_bytes: bytes,
    ) -> list[float]:
        """
        Convert raw image bytes into a normalized
        768-dimensional DINOv2 embedding.
        """

        if not image_bytes:
            raise ValueError(
                "Image is empty."
            )

        # -----------------------------------------------------
        # Decode uploaded image
        # -----------------------------------------------------

        try:
            with Image.open(
                BytesIO(image_bytes)
            ) as image:
                rgb_image = image.convert("RGB")

        except UnidentifiedImageError as exc:
            raise ValueError(
                "Uploaded file is not a valid image."
            ) from exc

        except Exception as exc:
            raise ValueError(
                f"Could not decode image: {exc}"
            ) from exc

        # -----------------------------------------------------
        # Preprocess image
        # -----------------------------------------------------

        inputs = self.processor(
            images=rgb_image,
            return_tensors="pt",
        )

        # Move tensors to the same device as model.
        inputs = {
            name: tensor.to(self.device)
            for name, tensor
            in inputs.items()
        }

        # -----------------------------------------------------
        # Generate embedding
        # -----------------------------------------------------

        with self._inference_lock:
            with torch.inference_mode():
                outputs = self.model(
                    **inputs
                )

                # Shape:
                #
                # [batch, tokens, hidden_size]
                #
                # token 0 = CLS token
                #
                # CLS represents the entire image.
                cls_embedding = (
                    outputs
                    .last_hidden_state[:, 0, :]
                )

                # -------------------------------------------------
                # L2 normalization
                # -------------------------------------------------
                #
                # This makes cosine similarity easier later.
                #
                # For normalized vectors:
                #
                # cosine similarity == dot product
                #
                cls_embedding = F.normalize(
                    cls_embedding,
                    p=2,
                    dim=1,
                )

        # -----------------------------------------------------
        # Tensor -> Python List<double>
        # -----------------------------------------------------

        vector = (
            cls_embedding[0]
            .detach()
            .cpu()
            .float()
            .tolist()
        )

        # -----------------------------------------------------
        # Defensive validation
        # -----------------------------------------------------

        if (
            len(vector)
            != EXPECTED_EMBEDDING_DIMENSION
        ):
            raise RuntimeError(
                "Embedding dimension mismatch: "
                f"expected "
                f"{EXPECTED_EMBEDDING_DIMENSION}, "
                f"got {len(vector)}."
            )

        return vector


@lru_cache(maxsize=1)
def get_dinov2_service() -> DinoV2Service:
    """
    Return a singleton DINOv2 service.

    DINOv2 is therefore loaded once rather than being
    reloaded for every image request.
    """

    return DinoV2Service()