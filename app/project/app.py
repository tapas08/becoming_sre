import os

import psycopg
from fastapi import FastAPI, HTTPException, Response
from psycopg.rows import dict_row
from pydantic import BaseModel

SERVICE = "project-api"
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://sre:sre@localhost:5432/app")

app = FastAPI(title=SERVICE)


class ProjectIn(BaseModel):
    project_name: str
    project_description: str = ""
    userid: int = 1


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


@app.post("/project/create", status_code=201)
def create_project(project: ProjectIn) -> dict:
    with db() as conn:
        row = conn.execute(
            "INSERT INTO projects (project_name, project_description, userid) VALUES (%s, %s, %s) RETURNING *",
            (project.project_name, project.project_description, project.userid),
        ).fetchone()
    return {"msg": "Project created", "data": row}


@app.get("/project/{project_id}")
def get_project(project_id: int) -> dict:
    with db() as conn:
        row = conn.execute("SELECT * FROM projects WHERE id = %s", (project_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Project not found")
    return {"msg": "Project found", "data": row}
