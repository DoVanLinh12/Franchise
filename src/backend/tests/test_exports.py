from io import BytesIO

from openpyxl import load_workbook

from app.services.export_service import contract_pdf, invoice_pdf, to_csv, to_xlsx


def test_csv_and_xlsx_exports():
    rows = [
        {"store": "S001", "gross_revenue": 1000},
        {"store": "S002", "gross_revenue": 2000},
    ]

    csv_content = to_csv(rows).decode("utf-8-sig")
    workbook = load_workbook(BytesIO(to_xlsx(rows)), read_only=True)

    assert "store,gross_revenue" in csv_content
    assert "S002,2000" in csv_content
    assert workbook.active["A2"].value == "S001"
    assert workbook.active["B3"].value == 2000


def test_pdf_exports_have_pdf_signature():
    contract = {
        "contract_no": "C-001",
        "store_id": "store-id",
        "royalty_rate": 5,
        "status": "ACTIVE",
    }
    invoice = {
        "invoice_no": "INV-001",
        "invoice_total": 1000,
        "outstanding_amount": 1000,
        "status": "ISSUED",
    }

    assert contract_pdf(contract).startswith(b"%PDF")
    assert invoice_pdf(invoice).startswith(b"%PDF")
