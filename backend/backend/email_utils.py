from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
from pydantic import EmailStr
from dotenv import load_dotenv
import os

load_dotenv()

conf = ConnectionConfig(
    MAIL_USERNAME=os.getenv("MAIL_USERNAME"),
    MAIL_PASSWORD=os.getenv("MAIL_PASSWORD"),
    MAIL_FROM=os.getenv("MAIL_FROM"),
    MAIL_PORT=587,
    MAIL_SERVER="smtp.gmail.com",
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
)


async def send_email(subject: str, email_to: EmailStr, body: str):
    try:
        message = MessageSchema(
            subject=subject, recipients=[email_to], body=body, subtype="html"
        )
        fm = FastMail(conf)
        await fm.send_message(message)
        print("📨 Email sent successfully!")
    except Exception as e:
        print("❌ Email sending error:", e)
