import json
import os
import random
import statistics
import urllib.request

import psycopg
from fastapi import FastAPI, HTTPException, Query, Response
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

SERVICE = "churn-api"
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://sre:sre@localhost:5432/app")
NOTIFICATION_URL = os.getenv("NOTIFICATION_URL", "http://localhost:8080")

app = FastAPI(title=SERVICE)


def db():
    return psycopg.connect(DATABASE_URL, row_factory=dict_row, connect_timeout=2)


def notify(message: str) -> None:
    body = json.dumps({"recipient": "admin", "message": message}).encode()
    req = urllib.request.Request(f"{NOTIFICATION_URL}/notify", data=body, headers={"Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=2)
    except OSError:
        pass


@app.get("/healthz")
def healthz(response: Response) -> dict:
    try:
        with db() as conn:
            conn.execute("SELECT 1")
        return {"service": SERVICE, "status": "ok"}
    except psycopg.Error:
        response.status_code = 503
        return {"service": SERVICE, "status": "db unavailable"}


@app.post("/churn/{project_id}", status_code=201)
def churn(project_id: int, rows: int = Query(100_000, ge=1, le=5_000_000)) -> dict:
    with db() as conn:
        if not conn.execute("SELECT 1 FROM projects WHERE id = %s", (project_id,)).fetchone():
            raise HTTPException(status_code=404, detail="Project not found")

    orders = [random.lognormvariate(3.5, 0.8) for _ in range(rows)]
    delivery_days = [random.randint(1, 10) for _ in range(rows)]
    metrics = {
        "rows_processed": rows,
        "total_revenue": round(sum(orders), 2),
        "avg_order_value": round(statistics.fmean(orders), 2),
        "p95_order_value": round(statistics.quantiles(orders, n=20)[-1], 2) if rows > 1 else orders[0],
        "late_delivery_pct": round(100 * sum(d > 7 for d in delivery_days) / rows, 2),
    }

    with db() as conn:
        row = conn.execute(
            "INSERT INTO kpis (project_id, metrics) VALUES (%s, %s) RETURNING *",
            (project_id, Jsonb(metrics)),
        ).fetchone()

    notify(f"Churn finished for project {project_id}: {rows} rows processed")
    return {"msg": "Churn complete", "data": row}
