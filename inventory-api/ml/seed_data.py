"""
Seeds the database with sample data so the forecasting model has
historical demand to learn from. Safe to re-run (checks before inserting).

Run from the inventory-api/ folder with the venv active:
    python3 ml/seed_data.py
"""
import os
import random
import sys
from datetime import datetime, timedelta

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # allow `from app...` imports

from app.database import SessionLocal
from app.models import Product, Warehouse, StockTransaction, Inventory

random.seed(42)

SAMPLE_PRODUCTS = [
    {"sku": "SKU-001", "name": "Wireless Mouse", "base_daily_demand": 8},
    {"sku": "SKU-002", "name": "USB-C Charging Cable", "base_daily_demand": 15},
    {"sku": "SKU-003", "name": "Mechanical Keyboard", "base_daily_demand": 4},
    {"sku": "SKU-004", "name": "Laptop Stand", "base_daily_demand": 6},
    {"sku": "SKU-005", "name": "Bluetooth Headphones", "base_daily_demand": 10},
]

DAYS_OF_HISTORY = 120


def seed():
    db = SessionLocal()
    try:
        # 1. Create one warehouse if none exists
        warehouse = db.query(Warehouse).first()
        if not warehouse:
            warehouse = Warehouse(name="Main Warehouse", location="Bengaluru, IN")
            db.add(warehouse)
            db.commit()
            db.refresh(warehouse)
            print(f"Created warehouse: {warehouse.name} (id={warehouse.warehouse_id})")

        # 2. Create products if they don't already exist
        products = []
        for p in SAMPLE_PRODUCTS:
            existing = db.query(Product).filter(Product.sku == p["sku"]).first()
            if existing:
                products.append((existing, p["base_daily_demand"]))
                continue
            new_product = Product(
                sku=p["sku"],
                name=p["name"],
                unit_price=random.uniform(10, 100),
                unit_cost=random.uniform(5, 60),
                reorder_point=p["base_daily_demand"] * 5,
                reorder_qty=p["base_daily_demand"] * 15,
            )
            db.add(new_product)
            db.commit()
            db.refresh(new_product)
            products.append((new_product, p["base_daily_demand"]))
            print(f"Created product: {new_product.name} (id={new_product.product_id})")

        # 3. Generate historical transactions with a weekly seasonality + slight upward trend
        #    This gives the forecasting model something realistic to learn from.
        start_date = datetime.now() - timedelta(days=DAYS_OF_HISTORY)

        # Skip seeding transactions if they already exist (avoid duplicate runs)
        existing_txn_count = db.query(StockTransaction).count()
        if existing_txn_count > 0:
            print(f"Transactions already exist ({existing_txn_count} rows) — skipping transaction seeding.")
            return

        for day_offset in range(DAYS_OF_HISTORY):
            current_date = start_date + timedelta(days=day_offset)
            is_weekend = current_date.weekday() >= 5
            trend_multiplier = 1 + (day_offset / DAYS_OF_HISTORY) * 0.3  # gentle 30% growth over the period

            for product, base_demand in products:
                # Weekend demand dips ~30%; add random noise
                demand = base_demand * (0.7 if is_weekend else 1.0) * trend_multiplier
                units_sold = max(0, int(random.gauss(demand, demand * 0.25)))

                if units_sold > 0:
                    txn = StockTransaction(
                        product_id=product.product_id,
                        warehouse_id=warehouse.warehouse_id,
                        transaction_type="outbound",
                        quantity=units_sold,
                        reference_note="seed data",
                        transaction_date=current_date,
                    )
                    db.add(txn)

                # Restock every 10 days
                if day_offset % 10 == 0:
                    restock_qty = base_demand * 12
                    txn_in = StockTransaction(
                        product_id=product.product_id,
                        warehouse_id=warehouse.warehouse_id,
                        transaction_type="inbound",
                        quantity=restock_qty,
                        reference_note="seed data - restock",
                        transaction_date=current_date,
                    )
                    db.add(txn_in)

        db.commit()
        print(f"Seeded {DAYS_OF_HISTORY} days of transaction history for {len(products)} products.")

        # 4. Set a reasonable current inventory snapshot per product
        for product, base_demand in products:
            inv = Inventory(
                product_id=product.product_id,
                warehouse_id=warehouse.warehouse_id,
                quantity_on_hand=base_demand * 8,
            )
            db.add(inv)
        db.commit()
        print("Initialized current inventory levels.")

    finally:
        db.close()


if __name__ == "__main__":
    seed()
