from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime


class ProductBase(BaseModel):
    sku: str
    name: str
    description: Optional[str] = None
    category_id: Optional[int] = None
    supplier_id: Optional[int] = None
    unit_price: float = 0
    unit_cost: float = 0
    reorder_point: int = 10
    reorder_qty: int = 50
    is_active: bool = True


class ProductCreate(ProductBase):
    """Used for POST — same fields as base, nothing extra needed yet."""
    pass


class ProductUpdate(BaseModel):
    """All fields optional — used for PATCH, only send what changed."""
    sku: Optional[str] = None
    name: Optional[str] = None
    description: Optional[str] = None
    category_id: Optional[int] = None
    supplier_id: Optional[int] = None
    unit_price: Optional[float] = None
    unit_cost: Optional[float] = None
    reorder_point: Optional[int] = None
    reorder_qty: Optional[int] = None
    is_active: Optional[bool] = None


class ProductOut(ProductBase):
    model_config = ConfigDict(from_attributes=True)  # lets Pydantic read SQLAlchemy objects directly

    product_id: int
    created_at: datetime
    updated_at: datetime


class StockTransactionCreate(BaseModel):
    product_id: int
    warehouse_id: int
    transaction_type: str  # inbound, outbound, adjustment, return
    quantity: int
    reference_note: Optional[str] = None


class StockTransactionOut(StockTransactionCreate):
    model_config = ConfigDict(from_attributes=True)

    transaction_id: int
    transaction_date: datetime
