import hashlib
import os

import psycopg
from fastapi import FastAPI, HTTPException, Response
from psycopg.rows import dict_row
from pydantic import BaseModel

SERVICE = "user-api"
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://sre:sre@localhost:5432/app")

app = FastAPI(title=SERVICE)


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
