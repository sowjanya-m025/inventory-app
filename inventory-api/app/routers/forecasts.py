from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel, ConfigDict

from app.database import get_db
from app.models import DemandForecast, Product, Inventory

router = APIRouter(prefix="/forecasts", tags=["Demand Forecasting"])


class ForecastOut(BaseModel):
    model_config = ConfigDict(from_attributes=True, protected_namespaces=())

    forecast_id: int
    product_id: int
    warehouse_id: Optional[int]
    forecast_date: datetime
    predicted_demand: float
    lower_bound: Optional[float]
    upper_bound: Optional[float]
    model_version: str


@router.get("/{product_id}", response_model=List[ForecastOut])
def get_forecast_for_product(product_id: int, days: int = 30, db: Session = Depends(get_db)):
    """Returns the forecasted demand for a product for the next N days."""
    product = db.query(Product).filter(Product.product_id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    forecasts = (
        db.query(DemandForecast)
        .filter(DemandForecast.product_id == product_id)
        .order_by(DemandForecast.forecast_date)
        .limit(days)
        .all()
    )
    if not forecasts:
        raise HTTPException(
            status_code=404,
            detail="No forecast available for this product yet. Run ml/train_forecast.py first.",
        )
    return forecasts


@router.get("/{product_id}/reorder-suggestion")
def get_reorder_suggestion(product_id: int, db: Session = Depends(get_db)):
    """
    Compares current stock against forecasted demand to suggest whether
    (and how much) to reorder. This is the payoff of the whole forecasting pipeline.
    """
    product = db.query(Product).filter(Product.product_id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    inv = db.query(Inventory).filter(Inventory.product_id == product_id).first()
    current_stock = inv.quantity_on_hand if inv else 0

    # Sum forecasted demand over the next 14 days (a reasonable lead-time window)
    next_14_days = (
        db.query(DemandForecast)
        .filter(DemandForecast.product_id == product_id)
        .order_by(DemandForecast.forecast_date)
        .limit(14)
        .all()
    )

    if not next_14_days:
        raise HTTPException(status_code=404, detail="No forecast available yet.")

    predicted_demand_14d = sum(float(f.predicted_demand) for f in next_14_days)
    projected_shortfall = predicted_demand_14d - current_stock

    return {
        "product_id": product_id,
        "product_name": product.name,
        "current_stock": current_stock,
        "predicted_demand_next_14_days": round(predicted_demand_14d, 1),
        "reorder_recommended": projected_shortfall > 0,
        "suggested_reorder_qty": max(0, round(projected_shortfall + product.reorder_qty * 0.2, 0)),
    }
