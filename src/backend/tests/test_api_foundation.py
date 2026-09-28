import pytest


@pytest.mark.asyncio
async def test_openapi_contains_auth_and_business_routes(client):
    response = await client.get("/openapi.json")

    assert response.status_code == 200
    paths = response.json()["paths"]
    assert "/api/v1/auth/login" in paths
    assert "/api/v1/applications" in paths
    assert "/api/v1/revenues" in paths
    assert "/api/v1/invoices/generate" in paths
    assert "/api/v1/reports/financial-summary/export" in paths


@pytest.mark.asyncio
async def test_protected_route_rejects_missing_bearer_token(client):
    response = await client.get("/api/v1/stores")

    assert response.status_code == 401
