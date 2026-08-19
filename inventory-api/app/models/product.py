from sqlalchemy import Column, Integer, String, Text, Numeric, Boolean, ForeignKey, TIMESTAMP
from sqlalchemy.sql import func
from app.database import Base


class Category(Base):
    __tablename__ = "categories"

    category_id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False, unique=True)
    parent_id = Column(Integer, ForeignKey("categories.category_id"), nullable=True)


class Supplier(Base):
    __tablename__ = "suppliers"

    supplier_id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), nullable=False)
    contact_email = Column(String(120))
    contact_phone = Column(String(30))
    address = Column(Text)
    created_at = Column(TIMESTAMP, server_default=func.now())


class Warehouse(Base):
    __tablename__ = "warehouses"

    warehouse_id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    location = Column(String(200))
    created_at = Column(TIMESTAMP, server_default=func.now())


class Product(Base):
    __tablename__ = "products"

    product_id = Column(Integer, primary_key=True, index=True)
    sku = Column(String(50), nullable=False, unique=True, index=True)
    name = Column(String(200), nullable=False)
    description = Column(Text)
    category_id = Column(Integer, ForeignKey("categories.category_id"), nullable=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.supplier_id"), nullable=True)
    unit_price = Column(Numeric(10, 2), default=0)
    unit_cost = Column(Numeric(10, 2), default=0)
    reorder_point = Column(Integer, default=10)
    reorder_qty = Column(Integer, default=50)
    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())


class Inventory(Base):
    __tablename__ = "inventory"

    inventory_id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=False)
    quantity_on_hand = Column(Integer, default=0)
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())


class StockTransaction(Base):
    __tablename__ = "stock_transactions"

    transaction_id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.user_id"), nullable=True)
    transaction_type = Column(String(20), nullable=False)  # inbound, outbound, adjustment, return
    quantity = Column(Integer, nullable=False)
    reference_note = Column(String(255))
    transaction_date = Column(TIMESTAMP, server_default=func.now())


class InventorySnapshot(Base):
    __tablename__ = "inventory_snapshots"

    snapshot_id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=False)
    snapshot_date = Column(TIMESTAMP, nullable=False)  # stored as date-only value
    quantity_on_hand = Column(Integer, nullable=False)
    units_sold = Column(Integer, default=0)
    units_received = Column(Integer, default=0)


class DemandForecast(Base):
    __tablename__ = "demand_forecasts"

    forecast_id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=True)
    forecast_date = Column(TIMESTAMP, nullable=False)
    predicted_demand = Column(Numeric(10, 2), nullable=False)
    lower_bound = Column(Numeric(10, 2))
    upper_bound = Column(Numeric(10, 2))
    model_version = Column(String(50), nullable=False)
    generated_at = Column(TIMESTAMP, server_default=func.now())
