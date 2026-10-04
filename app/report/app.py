import os

import psycopg
from fastapi import FastAPI, HTTPException, Response
from psycopg.rows import dict_row

SERVICE = "report-api"
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://sre:sre@localhost:5432/app")

app = FastAPI(title=SERVICE)


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


@app.get("/report/{project_id}")
def report(project_id: int) -> dict:
    with db() as conn:
        project = conn.execute("SELECT * FROM projects WHERE id = %s", (project_id,)).fetchone()
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        kpis = conn.execute(
            "SELECT metrics, c_time FROM kpis WHERE project_id = %s ORDER BY id DESC LIMIT 10", (project_id,)
        ).fetchall()
    return {"msg": "Report", "data": {"project": project, "kpis": kpis}}
