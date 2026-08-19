# AI-Driven Smart Inventory Management System

A cross-platform inventory management system with AI-powered demand forecasting, built with FastAPI, PostgreSQL, and Python — with automated testing and CI/CD via GitHub Actions.

## Features

- **REST API** for full CRUD on products, stock transactions, and inventory levels
- **Real-time inventory sync** — every stock transaction (inbound/outbound/adjustment/return) automatically updates on-hand quantities
- **AI demand forecasting** — Holt-Winters Exponential Smoothing model predicts 30-day demand per product, capturing trend and weekly seasonality
- **Reorder recommendations** — compares forecasted demand against current stock to suggest what to reorder and how much
- **Automated testing** — 14+ pytest tests covering CRUD, transactions, and edge cases
- **CI/CD pipeline** — GitHub Actions runs the full test suite on every push/PR, builds a Docker image on merge to `main`

## Tech Stack

| Layer | Technology |
|---|---|
| API | FastAPI (Python) |
| Database | PostgreSQL |
| ORM | SQLAlchemy |
| AI/Forecasting | statsmodels (Holt-Winters Exponential Smoothing), pandas |
| Testing | pytest, httpx (in-memory SQLite for test isolation) |
| CI/CD | GitHub Actions, Docker |
| Local dev environment | Docker Compose (Postgres + pgAdmin) |

## Architecture

```
Flutter App  ──────►  FastAPI (REST API)  ──────►  PostgreSQL
                              │
                              ▼
                    Holt-Winters Forecasting Model
                    (trained offline, predictions
                     stored in demand_forecasts table)
                              │
                              ▼
                        Power BI Dashboards
```

## Project Structure

```
inventory-api/
├── app/
│   ├── main.py              # FastAPI app entrypoint
│   ├── database.py          # DB connection/session management
│   ├── schemas.py           # Pydantic request/response models
│   ├── models/               # SQLAlchemy ORM models
│   └── routers/
│       ├── products.py       # Product CRUD endpoints
│       ├── transactions.py   # Stock transaction endpoints
│       └── forecasts.py      # Demand forecasting endpoints
├── ml/
│   ├── seed_data.py          # Generates sample historical data
│   ├── build_snapshots.py    # Aggregates transactions into daily snapshots
│   └── train_forecast.py     # Trains the forecasting model
├── tests/                    # Pytest test suite
├── schema.sql                 # Database schema
├── docker-compose.yml          # Local Postgres + pgAdmin
├── Dockerfile                  # Container image for the API
└── .github/workflows/ci-cd.yml # CI/CD pipeline
```

## Getting Started

### 1. Start the database

```bash
docker compose up -d
```

This starts PostgreSQL on `localhost:5432` and pgAdmin on `localhost:5050`, and automatically loads `schema.sql` on first startup.

### 2. Set up the API

```bash
cd inventory-api
python3 -m venv venv
source venv/bin/activate       # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Run the API

```bash
python3 -m uvicorn app.main:app --reload
```

Visit `http://127.0.0.1:8000/docs` for interactive API documentation.

### 4. Generate sample data and train the forecasting model

```bash
pip install -r ml/requirements.txt
python3 ml/seed_data.py
python3 ml/build_snapshots.py
python3 ml/train_forecast.py
```

### 5. Run tests

```bash
pytest tests/ -v
```

## Key API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/products/` | Create a product |
| `GET` | `/products/` | List all products |
| `GET` | `/products/{id}` | Get a single product |
| `PATCH` | `/products/{id}` | Update a product |
| `DELETE` | `/products/{id}` | Delete a product |
| `POST` | `/transactions/` | Record a stock movement (auto-updates inventory) |
| `GET` | `/transactions/` | List stock transaction history |
| `GET` | `/forecasts/{product_id}` | Get 30-day demand forecast |
| `GET` | `/forecasts/{product_id}/reorder-suggestion` | Get a reorder recommendation |

## Why Holt-Winters over Prophet?

Holt-Winters Exponential Smoothing was chosen for the forecasting model because it captures trend and weekly seasonality effectively while installing cleanly via `statsmodels` — no C++/Stan compiler dependency, unlike Facebook Prophet, which makes it far more portable across environments.

## CI/CD Pipeline

Every push and pull request to `main` triggers:
1. **Test job** — installs dependencies, runs the full pytest suite
2. **Build job** (on push to `main` only, after tests pass) — builds a Docker image of the API

See `.github/workflows/ci-cd.yml` for details. The deploy step is left commented out — connect it to your hosting provider of choice (Render, Railway, Fly.io, AWS, etc.) when ready.

## Roadmap

- [ ] Flutter mobile/web client
- [ ] Power BI dashboards (inventory trends, demand vs. forecast, supplier performance)
- [ ] Authentication (JWT-based)
- [ ] Nightly scheduled job for snapshot building + model retraining
