import hashlib
import os

import psycopg
import time
from fastapi import FastAPI, HTTPException, Response
from psycopg.rows import dict_row
from pydantic import BaseModel
from prometheus_client import Counter, Histogram, make_asgi_app

SERVICE = "user-api"
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

class Credentials(BaseModel):
    username: str
    password: str


def db():
    return psycopg.connect(DATABASE_URL, row_factory=dict_row, connect_timeout=2)


def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


@app.get("/healthz")
def healthz(response: Response) -> dict:
    try:
        with db() as conn:
            conn.execute("SELECT 1")
        return {"service": SERVICE, "status": "ok"}
    except psycopg.Error:
        response.status_code = 503
        return {"service": SERVICE, "status": "db unavailable"}


@app.post("/login")
def login(creds: Credentials) -> dict:
    with db() as conn:
        user = conn.execute(
            "SELECT id, username FROM users WHERE username = %s AND password_hash = %s",
            (creds.username, hash_password(creds.password)),
        ).fetchone()
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {"msg": "Login successful", "data": {"username": user["username"], "userid": user["id"]}}


@app.post("/register", status_code=201)
def register(creds: Credentials) -> dict:
    try:
        with db() as conn:
            user = conn.execute(
                "INSERT INTO users (username, password_hash) VALUES (%s, %s) RETURNING id, username",
                (creds.username, hash_password(creds.password)),
            ).fetchone()
    except psycopg.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="Username already exists")
    return {"msg": "User registered", "data": {"username": user["username"], "userid": user["id"]}}

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
