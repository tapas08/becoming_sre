# Application
A sample application with micro-service architecture to be deployed on AWS.

This application will help users process huge amount of data and make business decisions.

This will be used to help with understanding basics to advanced concept.

# Whats in here
## Architecture
A simple micro-service architecture with following components,
1. UI - Application user interface
2. User Service - Authentication and User Management
3. Project Service - Manage user projects
4. Churner Service - Take huge amount of data, process it and outputs KPIs to help make business decision
5. Notification Service - Stores notifications sent by other services (churn notifies on completion)
6. Report Service - Serves KPI reports per project
7. Postgres - Shared database

## What can we do
* The application have internal controls that can increase or decrease the latency.
* Load test the application
* Reduce available resources so we can illustrate OOM or process evicted like situations



## Run locally
```bash
cd app
docker compose up -d --build
```

| Component        | URL                                   |
|------------------|---------------------------------------|
| UI (status page) | http://localhost:3000                 |
| user-api         | http://localhost:8001/docs            |
| project-api      | http://localhost:8002/docs            |
| churn-api        | http://localhost:8003/docs            |
| notification-api | http://localhost:8004/docs            |
| report-api       | http://localhost:8005/docs            |
| postgres         | localhost:5433 (user/pass/db: sre/sre/app) |

The UI also proxies every service under `/api/<service>/`, e.g. `http://localhost:3000/api/churn/churn/1?rows=500000`.

Seed data: user `admin` / `pro123`, project `1`.

Reset the database: `docker compose down -v`.
