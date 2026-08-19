from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import products, transactions, forecasts

app = FastAPI(
    title="AI-Driven Smart Inventory Management API",
    description="REST API for managing products, stock, and demand forecasts.",
    version="1.0.0",
)

# Allow the Flutter app (running on a different origin/port) to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten this to your app's actual origin before production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(products.router)
app.include_router(transactions.router)
app.include_router(forecasts.router)


@app.get("/")
def root():
    return {"status": "ok", "message": "Inventory API is running"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}
