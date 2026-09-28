import csv
from io import BytesIO, StringIO
from typing import Any

from openpyxl import Workbook
from openpyxl.utils import get_column_letter
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table


def to_csv(rows: list[dict[str, Any]]) -> bytes:
    output = StringIO()
    fieldnames = list(rows[0]) if rows else []
    writer = csv.DictWriter(output, fieldnames=fieldnames)
    if fieldnames:
        writer.writeheader()
        writer.writerows(rows)
    return output.getvalue().encode("utf-8-sig")


def to_xlsx(rows: list[dict[str, Any]], sheet_name: str = "Report") -> bytes:
    workbook = Workbook()
    sheet = workbook.active
    assert sheet is not None
    sheet.title = sheet_name[:31]
    if rows:
        headers = list(rows[0])
        sheet.append(headers)
        for row in rows:
            sheet.append([row.get(header) for header in headers])
        sheet.freeze_panes = "A2"
        sheet.auto_filter.ref = sheet.dimensions
        for index, column in enumerate(sheet.columns, start=1):
            width = min(max(len(str(cell.value or "")) for cell in column) + 2, 35)
            sheet.column_dimensions[get_column_letter(index)].width = width
    output = BytesIO()
    workbook.save(output)
    return output.getvalue()


def contract_pdf(contract: dict[str, Any]) -> bytes:
    rows: list[list[Any]] = [
        ["Contract number", contract.get("contract_no")],
        ["Store ID", contract.get("store_id")],
        ["Signed date", contract.get("signed_date")],
        ["Effective from", contract.get("effective_from")],
        ["Effective to", contract.get("effective_to")],
        ["Royalty rate", f"{contract.get('royalty_rate')}%"],
        ["Initial franchise fee", contract.get("initial_franchise_fee")],
        ["Deposit", contract.get("deposit_amount")],
        ["System fee", contract.get("system_fee")],
        ["Service fee", contract.get("service_fee")],
        ["Status", contract.get("status")],
    ]
    return _document("FRANCHISE CONTRACT", rows)


def invoice_pdf(invoice: dict[str, Any]) -> bytes:
    rows: list[list[Any]] = [
        ["Invoice number", invoice.get("invoice_no")],
        ["Period", invoice.get("period_month")],
        ["Royalty fee", invoice.get("royalty_fee")],
        ["System fee", invoice.get("system_fee")],
        ["Service fee", invoice.get("service_fee")],
        ["Brand promotion support", invoice.get("brand_promotion_support")],
        ["Taxable amount", invoice.get("taxable_amount")],
        ["VAT rate", f"{invoice.get('vat_rate')}%"],
        ["VAT amount", invoice.get("vat_amount")],
        ["Invoice total", invoice.get("invoice_total")],
        ["Paid", invoice.get("paid_amount")],
        ["Outstanding", invoice.get("outstanding_amount")],
        ["Status", invoice.get("status")],
        ["Due date", invoice.get("due_date")],
    ]
    return _document("FRANCHISE FEE INVOICE", rows)


def _document(title: str, rows: list[list[Any]]) -> bytes:
    output = BytesIO()
    document = SimpleDocTemplate(
        output,
        pagesize=A4,
        rightMargin=18 * mm,
        leftMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
    )
    styles = getSampleStyleSheet()
    table = Table(rows, colWidths=[65 * mm, 90 * mm])
    table.setStyle(
        [
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("BACKGROUND", (0, 0), (0, -1), colors.whitesmoke),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
            ("PADDING", (0, 0), (-1, -1), 6),
        ]
    )
    document.build(
        [Paragraph(title, styles["Title"]), Spacer(1, 8 * mm), table]
    )
    return output.getvalue()
