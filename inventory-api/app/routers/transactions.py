from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database import get_db
from app.models import StockTransaction, Inventory, Product
from app.schemas import StockTransactionCreate, StockTransactionOut

router = APIRouter(prefix="/transactions", tags=["Stock Transactions"])

VALID_TYPES = {"inbound", "outbound", "adjustment", "return"}


@router.post("/", response_model=StockTransactionOut, status_code=201)
def create_transaction(txn: StockTransactionCreate, db: Session = Depends(get_db)):
    if txn.transaction_type not in VALID_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"transaction_type must be one of {sorted(VALID_TYPES)}",
        )

    product = db.query(Product).filter(Product.product_id == txn.product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    # 1. Log the movement in the ledger (source of truth for forecasting later)
    new_txn = StockTransaction(**txn.model_dump())
    db.add(new_txn)

    # 2. Keep the fast-lookup `inventory` table in sync
    inv = (
        db.query(Inventory)
        .filter(
            Inventory.product_id == txn.product_id,
            Inventory.warehouse_id == txn.warehouse_id,
        )
        .first()
    )
    if not inv:
        inv = Inventory(product_id=txn.product_id, warehouse_id=txn.warehouse_id, quantity_on_hand=0)
        db.add(inv)

    if txn.transaction_type in ("inbound", "return"):
        inv.quantity_on_hand += txn.quantity
    elif txn.transaction_type == "outbound":
        if inv.quantity_on_hand < txn.quantity:
            raise HTTPException(status_code=400, detail="Not enough stock on hand for this outbound transaction")
        inv.quantity_on_hand -= txn.quantity
    elif txn.transaction_type == "adjustment":
        inv.quantity_on_hand = txn.quantity  # adjustment sets the absolute count

    db.commit()
    db.refresh(new_txn)
    return new_txn


@router.get("/", response_model=List[StockTransactionOut])
def list_transactions(
    product_id: Optional[int] = None,
    warehouse_id: Optional[int] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    query = db.query(StockTransaction)
    if product_id is not None:
        query = query.filter(StockTransaction.product_id == product_id)
    if warehouse_id is not None:
        query = query.filter(StockTransaction.warehouse_id == warehouse_id)
    return query.order_by(StockTransaction.transaction_date.desc()).offset(skip).limit(limit).all()
