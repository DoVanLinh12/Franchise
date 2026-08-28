from celery import Celery

from app.config import settings

celery_app = Celery(
    "franchise",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)
