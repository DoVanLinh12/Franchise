import csv
from datetime import date
from decimal import Decimal
from io import BytesIO, StringIO
from typing import Annotated, Any
from uuid import UUID

import asyncpg
from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import Response
from openpyxl import load_workbook

from app.api.dependencies import CurrentUser
from app.exceptions import BusinessError
from app.services.contract_service import ContractService
from app.services.export_service import contract_pdf, invoice_pdf, to_csv, to_xlsx
from app.services.operations_service import OperationsService

router = APIRouter(tags=["Import and Export"])


def _user_id(user: dict[str, Any]) -> UUID:
    return UUID(str(user["id"]))


@router.get("/contracts/{contract_id}/pdf")
async def export_contract_pdf(
    contract_id: UUID, user: CurrentUser
) -> Response:
    contract = await ContractService().get_by_id(contract_id)
    if contract is None:
        raise HTTPException(status_code=404, detail="Contract not found")
    await OperationsService().assert_store_access(
        _user_id(user), UUID(str(contract["store_id"]))
    )
    return Response(
        contract_pdf(contract),
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="contract-{contract_id}.pdf"'
        },
    )


@router.get("/invoices/{invoice_id}/pdf")
async def export_invoice_pdf(invoice_id: UUID, user: CurrentUser) -> Response:
    invoice = await OperationsService().get_record("invoice", invoice_id)
    await OperationsService().assert_store_access(
        _user_id(user), UUID(str(invoice["store_id"]))
    )
    return Response(
        invoice_pdf(invoice),
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="invoice-{invoice_id}.pdf"'
        },
    )


@router.get("/reports/financial-summary/export")
async def export_financial_summary(
    period_from: date,
    period_to: date,
    format: str,
    user: CurrentUser,
) -> Response:
    rows = await OperationsService().financial_summary(
        _user_id(user), period_from, period_to
    )
    if format.lower() == "csv":
        content = to_csv(rows)
        media_type = "text/csv"
        filename = "financial-summary.csv"
    elif format.lower() == "xlsx":
        content = to_xlsx(rows, "Financial Summary")
        media_type = (
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        filename = "financial-summary.xlsx"
    else:
        raise HTTPException(status_code=422, detail="Format must be csv or xlsx")
    return Response(
        content,
        media_type=media_type,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/revenues/import")
async def import_revenues(
    user: CurrentUser, file: Annotated[UploadFile, File()]
) -> dict[str, Any]:
    content = await file.read()
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File is too large")
    try:
        rows = _read_rows(file.filename or "", content)
    except (ValueError, KeyError) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    if len(rows) > 5000:
        raise HTTPException(status_code=422, detail="Maximum 5000 rows")

    result: dict[str, Any] = {
        "total_rows": len(rows),
        "success_rows": 0,
        "failed_rows": 0,
        "errors": [],
    }
    service = OperationsService()
    for index, row in enumerate(rows, start=2):
        try:
            await service.save_revenue(
                None,
                UUID(str(row["store_id"])),
                _user_id(user),
                {
                    "business_date": date.fromisoformat(
                        str(row["business_date"])
                    ),
                    "gross_revenue": Decimal(str(row["gross_revenue"])),
                    "note": row.get("note"),
                    "promotion_details": [],
                },
            )
            result["success_rows"] += 1
        except (BusinessError, asyncpg.PostgresError, ValueError, KeyError) as exc:
            result["failed_rows"] += 1
            result["errors"].append({"row": index, "error": str(exc)})
    return result


def _read_rows(filename: str, content: bytes) -> list[dict[str, Any]]:
    if filename.lower().endswith(".csv"):
        return list(csv.DictReader(StringIO(content.decode("utf-8-sig"))))
    if filename.lower().endswith(".xlsx"):
        workbook = load_workbook(BytesIO(content), read_only=True, data_only=True)
        sheet = workbook.active
        assert sheet is not None
        values = list(sheet.iter_rows(values_only=True))
        if not values:
            return []
        headers = [str(value) for value in values[0]]
        return [dict(zip(headers, row, strict=False)) for row in values[1:]]
    raise ValueError("Only CSV and XLSX files are supported")
