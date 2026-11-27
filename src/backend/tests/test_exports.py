from io import BytesIO

from openpyxl import load_workbook

from app.services.export_service import (
    amount_in_words,
    contract_pdf,
    financial_report_rows,
    invoice_pdf,
    pct,
    to_csv,
    to_xlsx,
)


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


def test_amount_in_words_reads_vietnamese():
    assert amount_in_words(0) == "Không đồng"
    assert amount_in_words(15) == "Mười lăm đồng"
    assert amount_in_words(105) == "Một trăm lẻ năm đồng"
    assert amount_in_words(21) == "Hai mươi mốt đồng"
    assert amount_in_words(1250000) == "Một triệu hai trăm năm mươi nghìn đồng"
    assert amount_in_words(20472595) == (
        "Hai mươi triệu bốn trăm bảy mươi hai nghìn năm trăm chín mươi lăm đồng"
    )
    assert amount_in_words(1005000) == "Một triệu không trăm lẻ năm nghìn đồng"


def test_percentage_uses_vietnamese_decimal_comma():
    assert pct("5.0000") == "5"
    assert pct("5.5") == "5,5"


def test_financial_report_has_vietnamese_headers_and_totals():
    rows = [
        {"store_code": "HN-01", "store_name": "A", "gross_revenue": 100,
         "promotion_discount": 10, "net_revenue": 90, "royalty_fee": 5,
         "brand_support": 10, "invoice_total": 7, "paid_amount": 7,
         "outstanding_amount": 0},
        {"store_code": "HN-02", "store_name": "B", "gross_revenue": 200,
         "promotion_discount": 0, "net_revenue": 200, "royalty_fee": 10,
         "brand_support": 0, "invoice_total": 14, "paid_amount": 4,
         "outstanding_amount": 10},
    ]
    headers, body = financial_report_rows(rows)
    assert headers[0] == "Mã cửa hàng" and headers[-1] == "Còn phải thu (đ)"
    assert body[-1][:3] == ["TỔNG CỘNG", "2 cửa hàng", 300]
    assert body[-1][-1] == 10
    content = to_csv(rows, headers, body, ["BÁO CÁO"]).decode("utf-8-sig")
    assert content.splitlines()[0] == "BÁO CÁO"
    assert "TỔNG CỘNG,2 cửa hàng,300" in content
    workbook = load_workbook(BytesIO(to_xlsx(rows, "Báo cáo", headers, body, ["BÁO CÁO"])))
    sheet = workbook.active
    assert sheet["A1"].value == "BÁO CÁO"
    assert sheet["A3"].value == "Mã cửa hàng"
    assert sheet["C6"].value == 300


def test_documents_render_vietnamese_with_full_data():
    contract = {"contract_no": "HĐNQ-2026-001", "status": "DRAFT", "store_code": "HN-01",
                "store_name": "Mộc Miên Coffee Hoàn Kiếm", "store_address": "38 Hàng Bông",
                "owner_name": "Lê Minh Anh", "signed_date": "2026-11-01",
                "effective_from": "2026-11-05", "effective_to": "2031-11-05",
                "royalty_rate": "5.0000", "initial_franchise_fee": 180000000,
                "deposit_amount": 50000000, "system_fee": 1500000, "service_fee": 2500000}
    invoice = {"invoice_no": "PNQ-202610-HN-01", "status": "PAID", "period_month": "2026-10-01",
               "royalty_rate": "5.0000", "vat_rate": "10.0000", "invoice_total": 21712240,
               "payments": [{"payment_no": "TT-1", "payment_date": "2026-11-09",
                             "amount": 21712240, "method": "BANK_TRANSFER",
                             "status": "CONFIRMED"}]}
    assert contract_pdf(contract).startswith(b"%PDF")
    assert invoice_pdf(invoice).startswith(b"%PDF")
