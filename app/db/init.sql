CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    c_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    project_name TEXT NOT NULL,
    project_description TEXT,
    userid INT REFERENCES users(id),
    c_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE kpis (
    id SERIAL PRIMARY KEY,
    project_id INT REFERENCES projects(id),
    metrics JSONB NOT NULL,
    c_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    recipient TEXT NOT NULL,
    message TEXT NOT NULL,
    c_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO users (username, password_hash) VALUES ('admin', encode(sha256('pro123'::bytea), 'hex'));
INSERT INTO projects (project_name, project_description, userid) VALUES ('Project X', 'Parse the shipping data.', 1);
