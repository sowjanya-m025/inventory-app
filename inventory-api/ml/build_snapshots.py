"""
Aggregates stock_transactions into daily inventory_snapshots rows.
This turns messy transaction-level data into a clean daily time series,
which is what the forecasting model actually trains on.

In production, run this nightly (cron job or scheduled task).
For now, run it manually after seeding data:
    python3 ml/build_snapshots.py
"""
import os
import sys
from datetime import datetime, timedelta
from collections import defaultdict

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal
from app.models import StockTransaction, InventorySnapshot, Product, Warehouse


def build_snapshots():
    db = SessionLocal()
    try:
        transactions = db.query(StockTransaction).order_by(StockTransaction.transaction_date).all()
        if not transactions:
            print("No transactions found. Run ml/seed_data.py first.")
            return

        # Group transactions by (product_id, warehouse_id, date)
        daily_totals = defaultdict(lambda: {"sold": 0, "received": 0})
        for txn in transactions:
            day = txn.transaction_date.date()
            key = (txn.product_id, txn.warehouse_id, day)
            if txn.transaction_type == "outbound":
                daily_totals[key]["sold"] += txn.quantity
            elif txn.transaction_type in ("inbound", "return"):
                daily_totals[key]["received"] += txn.quantity

        # Clear existing snapshots to avoid duplicates on re-run
        db.query(InventorySnapshot).delete()
        db.commit()

        # Running stock balance per (product, warehouse), built up day by day
        running_stock = defaultdict(int)
        sorted_keys = sorted(daily_totals.keys(), key=lambda k: k[2])  # sort by date

        inserted = 0
        for product_id, warehouse_id, day in sorted_keys:
            totals = daily_totals[(product_id, warehouse_id, day)]
            running_key = (product_id, warehouse_id)
            running_stock[running_key] += totals["received"] - totals["sold"]

            snapshot = InventorySnapshot(
                product_id=product_id,
                warehouse_id=warehouse_id,
                snapshot_date=datetime.combine(day, datetime.min.time()),
                quantity_on_hand=max(0, running_stock[running_key]),
                units_sold=totals["sold"],
                units_received=totals["received"],
            )
            db.add(snapshot)
            inserted += 1

        db.commit()
        print(f"Built {inserted} daily snapshot rows across all products and warehouses.")

    finally:
        db.close()


if __name__ == "__main__":
    build_snapshots()
