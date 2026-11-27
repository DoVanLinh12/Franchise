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
from app.services.export_service import (
    contract_pdf,
    financial_report_rows,
    invoice_pdf,
    to_csv,
    to_xlsx,
)
from app.services.operations_service import OperationsService

router = APIRouter(tags=["Import and Export"])


def _user_id(user: dict[str, Any]) -> UUID:
    return UUID(str(user["id"]))


@router.get("/contracts/{contract_id}/pdf")
async def export_contract_pdf(
    contract_id: UUID, user: CurrentUser
) -> Response:
    if await ContractService().get_by_id(contract_id) is None:
        raise HTTPException(status_code=404, detail="Contract not found")
    contract = await OperationsService().get_document("contract", contract_id)
    if contract.get("store_id"):
        await OperationsService().assert_store_access(
            _user_id(user), UUID(str(contract["store_id"]))
        )
    elif not {"ADMIN", "ACCOUNTANT"} & set(user.get("roles", [])):
        # Draft contract: the store does not exist until activation.
        raise HTTPException(status_code=403, detail="Insufficient permission")
    return Response(
        contract_pdf(contract),
        media_type="application/pdf",
        headers={
            "Content-Disposition": (
                f'attachment; filename="hop-dong-{contract.get("store_code")}.pdf"'
            )
        },
    )


@router.get("/invoices/{invoice_id}/pdf")
async def export_invoice_pdf(invoice_id: UUID, user: CurrentUser) -> Response:
    invoice = await OperationsService().get_document("invoice", invoice_id)
    await OperationsService().assert_store_access(
        _user_id(user), UUID(str(invoice["store_id"]))
    )
    return Response(
        invoice_pdf(invoice),
        media_type="application/pdf",
        headers={
            "Content-Disposition": (
                f'attachment; filename="thong-bao-phi-{invoice.get("invoice_no")}.pdf"'
            )
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
    headers, body = financial_report_rows(rows)
    title = [
        "BÁO CÁO TỔNG HỢP TÀI CHÍNH CHUỖI NHƯỢNG QUYỀN",
        f"Kỳ báo cáo: {period_from:%d/%m/%Y} - {period_to:%d/%m/%Y}",
        f"Người xuất: {user.get('full_name')} ({user.get('email')})",
    ]
    stamp = f"{period_from:%Y%m%d}-{period_to:%Y%m%d}"
    if format.lower() == "csv":
        content = to_csv(rows, headers, body, title)
        media_type = "text/csv; charset=utf-8"
        filename = f"bao-cao-tai-chinh-{stamp}.csv"
    elif format.lower() == "xlsx":
        content = to_xlsx(rows, "Báo cáo tài chính", headers, body, title)
        media_type = (
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        filename = f"bao-cao-tai-chinh-{stamp}.xlsx"
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
    stores, _ = await service.list_records(
        "stores", _user_id(user), None, None, 1, 200
    )
    store_ids = {str(store["code"]).upper(): str(store["id"]) for store in stores}
    for index, row in enumerate(rows, start=2):
        try:
            if row.get("store_code"):
                code = str(row["store_code"]).strip().upper()
                if code not in store_ids:
                    raise ValueError(f"STORE_NOT_FOUND:{code}")
                store_id = UUID(store_ids[code])
            else:
                store_id = UUID(str(row["store_id"]))
            await service.save_revenue(
                None,
                store_id,
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
