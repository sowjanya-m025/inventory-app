def _make_product_and_warehouse(client):
    product = client.post("/products/", json={"sku": "TXN-001", "name": "Transaction Test Item"}).json()
    return product["product_id"]


def test_inbound_transaction_increases_stock(client):
    product_id = _make_product_and_warehouse(client)

    response = client.post(
        "/transactions/",
        json={
            "product_id": product_id,
            "warehouse_id": 1,
            "transaction_type": "inbound",
            "quantity": 50,
        },
    )
    assert response.status_code == 201
    assert response.json()["quantity"] == 50


def test_outbound_exceeding_stock_rejected(client):
    product_id = _make_product_and_warehouse(client)

    # No stock yet — any outbound should be rejected
    response = client.post(
        "/transactions/",
        json={
            "product_id": product_id,
            "warehouse_id": 1,
            "transaction_type": "outbound",
            "quantity": 10,
        },
    )
    assert response.status_code == 400
    assert "Not enough stock" in response.json()["detail"]


def test_outbound_after_inbound_succeeds(client):
    product_id = _make_product_and_warehouse(client)

    client.post(
        "/transactions/",
        json={"product_id": product_id, "warehouse_id": 1, "transaction_type": "inbound", "quantity": 100},
    )
    response = client.post(
        "/transactions/",
        json={"product_id": product_id, "warehouse_id": 1, "transaction_type": "outbound", "quantity": 30},
    )
    assert response.status_code == 201


def test_invalid_transaction_type_rejected(client):
    product_id = _make_product_and_warehouse(client)

    response = client.post(
        "/transactions/",
        json={"product_id": product_id, "warehouse_id": 1, "transaction_type": "not_a_real_type", "quantity": 5},
    )
    assert response.status_code == 400
