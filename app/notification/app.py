import os

import psycopg
from fastapi import FastAPI, Query, Response
from psycopg.rows import dict_row
from pydantic import BaseModel

SERVICE = "notification-api"
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://sre:sre@localhost:5432/app")

app = FastAPI(title=SERVICE)


class Notification(BaseModel):
    recipient: str
    message: str


def db():
    return psycopg.connect(DATABASE_URL, row_factory=dict_row, connect_timeout=2)


@app.get("/healthz")
def healthz(response: Response) -> dict:
    try:
        with db() as conn:
            conn.execute("SELECT 1")
        return {"service": SERVICE, "status": "ok"}
    except psycopg.Error:
        response.status_code = 503
        return {"service": SERVICE, "status": "db unavailable"}


@app.post("/notify", status_code=201)
def notify(notification: Notification) -> dict:
    with db() as conn:
        row = conn.execute(
            "INSERT INTO notifications (recipient, message) VALUES (%s, %s) RETURNING *",
            (notification.recipient, notification.message),
        ).fetchone()
    return {"msg": "Notification sent", "data": row}


@app.get("/notifications")
def list_notifications(limit: int = Query(20, ge=1, le=100)) -> dict:
    with db() as conn:
        rows = conn.execute("SELECT * FROM notifications ORDER BY id DESC LIMIT %s", (limit,)).fetchall()
    return {"msg": "Notifications", "data": rows}
