import os
import time
import psycopg

from fastapi import FastAPI, Query, Response
from psycopg.rows import dict_row
from pydantic import BaseModel
from prometheus_client import Counter, Histogram, make_asgi_app

SERVICE = "notification-api"
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://sre:sre@localhost:5432/app")

app = FastAPI(title=SERVICE)
metrics_app = make_asgi_app()

REQUESTS = Counter(
    "http_requests_total",
    "HTTP requests",
    ["service", "method", "route", "code"],
)

LATENCY = Histogram(
    "http_request_duration_seconds",
    "Request latency",
    ["service", "method", "route"],
    buckets=(0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 0.8, 1.0, 2.0, 5.0),
)


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


app.mount("/metrics", metrics_app)

# App middleware to track requests and latency
@app.middleware("http")
async def track_requests(request, call_next):
    route = request.url.path
    method = request.method
    if route == "/metrics":
        return await call_next(request)
    start_time = time.perf_counter()
    response = await call_next(request)
    elapsed_time = time.perf_counter() - start_time
    REQUESTS.labels(service=SERVICE, method=method, route=route, code=str(response.status_code)).inc()
    LATENCY.labels(service=SERVICE, method=method, route=route).observe(elapsed_time)
    return response