from pydantic import BaseModel


class EmbeddingResponse(BaseModel):
    model: str
    dimension: int
    embedding: list[float]