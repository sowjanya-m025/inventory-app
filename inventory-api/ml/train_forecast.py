"""
Trains a per-product demand forecasting model using Holt-Winters
Exponential Smoothing (captures trend + weekly seasonality) and
writes the next 30 days of predictions into demand_forecasts.

Chosen over Prophet for this project because it installs cleanly
everywhere (pure statsmodels, no C++/Stan compiler needed) while
still handling trend + weekly seasonality well.

Run after build_snapshots.py:
    python3 ml/train_forecast.py
"""
import os
import sys
from datetime import datetime, timedelta

import pandas as pd
from statsmodels.tsa.holtwinters import ExponentialSmoothing

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal
from app.models import InventorySnapshot, Product, DemandForecast

FORECAST_HORIZON_DAYS = 30
MODEL_VERSION = "holtwinters_v1"
MIN_HISTORY_DAYS = 21  # need at least 3 weeks of data for weekly seasonality to mean anything


def train_and_forecast():
    db = SessionLocal()
    try:
        products = db.query(Product).all()
        if not products:
            print("No products found. Run ml/seed_data.py first.")
            return

        # Clear old forecasts from this model version to avoid stale duplicates
        db.query(DemandForecast).filter(DemandForecast.model_version == MODEL_VERSION).delete()
        db.commit()

        total_forecasts = 0

        for product in products:
            snapshots = (
                db.query(InventorySnapshot)
                .filter(InventorySnapshot.product_id == product.product_id)
                .order_by(InventorySnapshot.snapshot_date)
                .all()
            )

            if len(snapshots) < MIN_HISTORY_DAYS:
                print(f"Skipping {product.name}: only {len(snapshots)} days of history (need {MIN_HISTORY_DAYS}+)")
                continue

            # Build a daily demand series (units_sold per day)
            df = pd.DataFrame(
                [{"date": s.snapshot_date, "units_sold": s.units_sold} for s in snapshots]
            )
            df.set_index("date", inplace=True)
            series = df["units_sold"].asfreq("D", fill_value=0)  # fill missing days with 0 demand

            # Fit Holt-Winters: additive trend, additive weekly seasonality
            try:
                model = ExponentialSmoothing(
                    series,
                    trend="add",
                    seasonal="add",
                    seasonal_periods=7,
                    initialization_method="estimated",
                ).fit()
            except Exception as e:
                print(f"Model failed to fit for {product.name}: {e}")
                continue

            forecast = model.forecast(FORECAST_HORIZON_DAYS)
            residual_std = series.tail(30).std() if len(series) >= 30 else series.std()

            last_date = series.index[-1]
            warehouse_id = snapshots[-1].warehouse_id

            for i, predicted_value in enumerate(forecast, start=1):
                forecast_date = last_date + timedelta(days=i)
                predicted = max(0, round(float(predicted_value), 2))
                # Simple confidence band: +/- 1.5 standard deviations of recent demand
                lower = max(0, round(predicted - 1.5 * residual_std, 2))
                upper = round(predicted + 1.5 * residual_std, 2)

                db.add(
                    DemandForecast(
                        product_id=product.product_id,
                        warehouse_id=warehouse_id,
                        forecast_date=forecast_date,
                        predicted_demand=predicted,
                        lower_bound=lower,
                        upper_bound=upper,
                        model_version=MODEL_VERSION,
                    )
                )
                total_forecasts += 1

            print(f"Forecasted {product.name}: next-day demand ≈ {round(float(forecast.iloc[0]), 1)} units")

        db.commit()
        print(f"\nDone. Wrote {total_forecasts} forecast rows ({FORECAST_HORIZON_DAYS} days x products) to demand_forecasts.")

    finally:
        db.close()


if __name__ == "__main__":
    train_and_forecast()
