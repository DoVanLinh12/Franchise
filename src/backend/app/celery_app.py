import asyncio
import smtplib
from email.message import EmailMessage

from celery import Celery

from app.config import settings

celery_app = Celery(
    "franchise",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)
celery_app.conf.beat_schedule = {
    "generate-operational-alerts-hourly": {
        "task": "franchise.generate_operational_alerts",
        "schedule": 3600.0,
    }
}


@celery_app.task(name="franchise.generate_operational_alerts")
def generate_operational_alerts() -> None:
    async def run() -> None:
        from app.database import connect_database, disconnect_database
        from app.services.operations_service import OperationsService

        await connect_database()
        try:
            await OperationsService().generate_alerts()
        finally:
            await disconnect_database()

    asyncio.run(run())


@celery_app.task(name="franchise.send_email")
def send_email(recipient: str, subject: str, body: str) -> None:
    message = EmailMessage()
    message["From"] = settings.EMAIL_FROM
    message["To"] = recipient
    message["Subject"] = subject
    message.set_content(body)
    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as smtp:
        smtp.send_message(message)
