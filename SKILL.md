---
name: inventory-app
description: Work on the "inventory-app" project (github.com/sowjanya-m025/inventory-app) — an AI-driven smart inventory management system with a FastAPI/PostgreSQL backend (inventory-api) and a Flutter client (inventory_app). Use this skill whenever the user asks to add or modify API endpoints, database models, demand-forecasting logic, or Flutter screens/widgets in this repo, run its tests, work with its Docker/CI setup, or otherwise extend this specific codebase. Not for generic FastAPI/Flutter questions unrelated to this project.
---

# inventory-app

Conventions and architecture notes for `sowjanya-m025/inventory-app`, an AI-driven
smart inventory management system. Read this before making changes so new code
matches the existing style.

## Repo layout

```
inventory-app/
├── inventory-api/        # FastAPI backend
│   ├── app/
│   │   ├── main.py           # App entrypoint, CORS, router registration
│   │   ├── database.py       # DB session/connection (get_db dependency)
│   │   ├── schemas.py        # Pydantic request/response models
│   │   ├── models/           # SQLAlchemy ORM models (product.py, user.py, ...)
│   │   └── routers/          # One router module per resource
│   │       ├── products.py
│   │       ├── transactions.py
│   │       └── forecasts.py
│   ├── ml/                   # Forecasting pipeline (offline scripts, not API code)
│   │   ├── seed_data.py          # Generates sample historical data
│   │   ├── build_snapshots.py    # Aggregates transactions -> daily snapshots
│   │   ├── train_forecast.py     # Trains Holt-Winters model, writes forecasts
│   │   └── export_to_excel.py    # Exports data to inventory_export.xlsx
│   ├── tests/                # pytest suite (in-memory SQLite)
│   ├── schema.sql            # Postgres schema, auto-loaded by docker-compose
│   ├── docker-compose.yml    # Local Postgres + pgAdmin
│   ├── Dockerfile
│   └── requirements.txt
├── inventory_app/        # Flutter client
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/            # Dart data models (product.dart, transaction.dart, forecast.dart)
│   │   ├── screens/           # dashboard_screen.dart, add_product_screen.dart, product_detail_screen.dart
│   │   ├── services/          # api_service.dart — talks to inventory-api
│   │   └── widgets/           # product_card.dart, etc.
│   └── pubspec.yaml
└── schema.sql (top-level copy)
```

## Backend conventions (inventory-api)

- **Stack**: FastAPI + SQLAlchemy ORM + PostgreSQL, Pydantic v2 (`model_config = ConfigDict(from_attributes=True)` on `*Out` schemas, `model_dump()` / `model_dump(exclude_unset=True)` for writes).
- **Router pattern**: each resource gets its own `APIRouter(prefix="/products", tags=["Products"])` in `app/routers/<resource>.py`, registered in `main.py` via `app.include_router(...)`. Follow this pattern for any new resource.
- **Schema pattern** per resource in `schemas.py`:
  - `<Resource>Base` — shared fields
  - `<Resource>Create` — inherits Base, used for POST
  - `<Resource>Update` — all fields `Optional`, used for PATCH with `exclude_unset=True`
  - `<Resource>Out` — inherits Base, adds DB-generated fields (id, timestamps), sets `from_attributes=True`
- **Endpoint idioms**: use `Depends(get_db)` for the session; raise `HTTPException(status_code=404, ...)` when a lookup misses; raise `400` for conflicts (e.g. duplicate SKU); list endpoints take `skip`/`limit` plus optional filter query params and return `List[<Resource>Out]`.
- **Forecasting**: demand forecasting uses Holt-Winters Exponential Smoothing (`statsmodels`), chosen deliberately over Prophet to avoid a C++/Stan compiler dependency. Forecasts are trained offline via the `ml/` scripts and stored in a `demand_forecasts` table, then served read-only via `app/routers/forecasts.py`. Don't add online/real-time training inside API request handlers — keep training in `ml/train_forecast.py`.
- **Tests**: pytest with `httpx` against an in-memory SQLite DB for isolation (see `pytest.ini`, `tests/`). Run with `pytest tests/ -v`. Add tests alongside new endpoints, covering CRUD + edge cases, matching existing test style.
- **CI/CD**: GitHub Actions (`.github/workflows/ci-cd.yml`) runs the test job on every push/PR, and builds a Docker image on merge to `main`. The deploy step is intentionally left commented out.

### Local dev workflow

```bash
# 1. Start Postgres + pgAdmin (loads schema.sql automatically)
docker compose up -d

# 2. Backend env
cd inventory-api
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# 3. Run the API
python3 -m uvicorn app.main:app --reload   # docs at http://127.0.0.1:8000/docs

# 4. Seed data + train forecasting model
pip install -r ml/requirements.txt
python3 ml/seed_data.py
python3 ml/build_snapshots.py
python3 ml/train_forecast.py

# 5. Tests
pytest tests/ -v
```

## Flutter client conventions (inventory_app)

- Standard Flutter project layout: `lib/models` mirrors the API's Pydantic schemas (`product.dart`, `transaction.dart`, `forecast.dart`), `lib/services/api_service.dart` is the single place HTTP calls to `inventory-api` live, `lib/screens` holds top-level pages, `lib/widgets` holds reusable UI pieces.
- When the backend adds/changes a field on a resource, update the matching Dart model in `lib/models/` and the corresponding call in `api_service.dart` to keep the two in sync.
- This client is early-stage per the backend README's roadmap (Flutter client, Power BI dashboards, JWT auth, and a nightly retrain job are still open items) — expect gaps rather than a fully wired app.

## When extending this project

1. **New API resource**: add a SQLAlchemy model in `app/models/`, Pydantic schemas in `schemas.py` following the Base/Create/Update/Out pattern, a router in `app/routers/`, register it in `main.py`, add a matching pytest module in `tests/`, and update `schema.sql`.
2. **New Flutter screen/widget**: add the model in `lib/models/` if it doesn't exist, wire the API call through `lib/services/api_service.dart`, then build the screen/widget referencing existing screens for styling/navigation patterns.
3. **Forecasting changes**: modify `ml/train_forecast.py` (and `ml/build_snapshots.py` if the input aggregation changes) rather than embedding model logic in `app/routers/forecasts.py`, which should stay a thin read layer over `demand_forecasts`.
4. Keep CORS, Docker, and CI/CD config in mind — don't hardcode ports/origins that conflict with `docker-compose.yml` or the GitHub Actions workflow.
