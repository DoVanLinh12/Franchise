from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_BREAK, WD_LINE_SPACING, WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "API_BUSINESS_INPUT_GUIDE.docx"


def api(method, path, purpose, role, sample, note=""):
    return {
        "method": method,
        "path": path,
        "purpose": purpose,
        "role": role,
        "sample": sample,
        "note": note,
    }


BUSINESS = {
    "Hồ sơ nhượng quyền": [
        api("POST", "/applications", "Nộp hồ sơ đề nghị mở cửa hàng nhượng quyền.", "Người dùng đã đăng nhập", '''{
  "applicant_name": "Nguyễn Minh Khôi",
  "email": "nguyen.minh.khoi@franchise.local",
  "phone": "0916882233",
  "proposed_store_name": "Mộc Miên Coffee Hà Đông",
  "proposed_address": "22 Tố Hữu, phường Hà Cầu, quận Hà Đông, Hà Nội",
  "proposed_area": 135,
  "investment_budget": 2100000000,
  "note": "Mặt bằng gần khu đô thị, có chỗ đỗ xe và khu vực giao hàng riêng."
}''', "Số tiền tính bằng VND; diện tích tính bằng m². Trả về id hồ sơ mới."),
        api("GET", "/applications?status=PENDING&search=Hà Đông&page=1&page_size=20", "Tra cứu hồ sơ theo trạng thái hoặc tên người nộp/cửa hàng.", "Người dùng đã đăng nhập", "Query mẫu: status=PENDING, search=Hà Đông, page=1, page_size=20.", "Admin xem toàn bộ hồ sơ; người dùng thường chỉ xem hồ sơ của mình."),
        api("POST", "/applications/{application_id}/withdraw", "Rút hồ sơ chưa được chuyển thành cửa hàng.", "Chủ hồ sơ", '''{
  "reason": "Tạm hoãn kế hoạch đầu tư để tìm mặt bằng phù hợp hơn."
}''', "Thay {application_id} bằng UUID trong kết quả hồ sơ. Thành công trả 204."),
        api("POST", "/applications/{application_id}/start-review", "Chuyển hồ sơ sang trạng thái đang thẩm định.", "Admin", "Không có request body.", "Thay {application_id} bằng UUID hồ sơ. Thành công trả 204."),
        api("POST", "/applications/{application_id}/approve", "Duyệt hồ sơ nhượng quyền đạt yêu cầu.", "Admin", '''{
  "note": "Mặt bằng, diện tích và phương án đầu tư đáp ứng tiêu chuẩn nhượng quyền."
}''', "note có thể để null hoặc bỏ qua. Thành công trả 204."),
        api("POST", "/applications/{application_id}/reject", "Từ chối hồ sơ và lưu lý do.", "Admin", '''{
  "reason": "Mặt bằng chưa đạt diện tích tối thiểu và chưa có khu vực đỗ xe."
}''', "Thay {application_id} bằng UUID hồ sơ. Lý do là bắt buộc."),
    ],
    "Cửa hàng": [
        api("POST", "/stores", "Tạo cửa hàng từ hồ sơ đã được duyệt.", "Admin", '''{
  "application_id": "91000000-0000-0000-0000-000000000012",
  "owner_id": "90000000-0000-0000-0000-000000000013",
  "code": "HUE-PH-009",
  "name": "Mộc Miên Coffee Huế",
  "address": "41 Lê Lợi, phường Phú Hội, thành phố Huế",
  "phone": "02343811241",
  "email": "hue@mocmien.local"
}''', "UUID mẫu thuộc hồ sơ Huế đã APPROVED nhưng chưa chuyển thành Store và đúng người nộp hồ sơ trong seed. Đổi mã cửa hàng nếu bạn đã dùng mẫu này trước đó."),
        api("GET", "/stores?status=ACTIVE&search=Mộc Miên&page=1&page_size=20", "Liệt kê cửa hàng trong phạm vi tài khoản.", "Người dùng đã đăng nhập", "Query mẫu: status=ACTIVE, search=Mộc Miên, page=1, page_size=20.", "Chủ cửa hàng chỉ thấy cửa hàng của mình; Admin và Kế toán có phạm vi rộng hơn."),
    ],
    "Hợp đồng": [
        api("POST", "/contracts", "Tạo hợp đồng nhượng quyền ở trạng thái nháp.", "Admin", '''{
  "store_id": "92000000-0000-0000-0000-000000000007",
  "contract_no": "FRC-2026-QN-HL-009",
  "signed_date": "2026-09-28",
  "effective_from": "2026-10-01",
  "effective_to": "2031-09-30",
  "royalty_rate": 5.0,
  "initial_franchise_fee": 185000000,
  "deposit_amount": 55000000,
  "system_fee": 1500000,
  "service_fee": 2500000
}''', "store_id là UUID cửa hàng. Ví dụ dùng cửa hàng Hạ Long; contract_no phải duy nhất."),
        api("GET", "/contracts?status=ACTIVE&search=FRC-2025&page=1&page_size=20", "Tra cứu hợp đồng theo trạng thái hoặc mã hợp đồng.", "Người dùng đã đăng nhập", "Query mẫu: status=ACTIVE, search=FRC-2025, page=1, page_size=20."),
        api("POST", "/contracts/{contract_id}/financial-transactions", "Ghi nhận thanh toán phí ban đầu hoặc tiền ký quỹ.", "Admin", '''{
  "transaction_type": "DEPOSIT_PAYMENT",
  "amount": 55000000,
  "transaction_date": "2026-09-28",
  "reference_no": "VCB2609280091",
  "note": "Đã đối chiếu tiền ký quỹ qua sao kê ngân hàng."
}''', "transaction_type nhận INITIAL_FEE_PAYMENT hoặc DEPOSIT_PAYMENT. Số tiền cần phù hợp hợp đồng."),
        api("POST", "/contracts/{contract_id}/activate", "Kích hoạt hợp đồng sau khi hoàn tất các điều kiện thanh toán.", "Admin", "Không có request body.", "Thay {contract_id} bằng UUID hợp đồng nháp. Hệ thống yêu cầu hợp đồng đã ký và đã thanh toán tối thiểu 20% phí nhượng quyền ban đầu qua financial-transactions. Thành công trả 204."),
    ],
    "Khuyến mãi": [
        api("POST", "/promotions", "Tạo chương trình khuyến mãi và phạm vi cửa hàng áp dụng.", "Admin", '''{
  "name": "Tuần lễ khai trương Hà Đông",
  "description": "Giảm 15% đồ uống trong tuần khai trương cửa hàng.",
  "discount_type": "PERCENTAGE",
  "discount_value": 15,
  "start_date": "2026-10-01",
  "end_date": "2026-10-07",
  "scope": "SELECTED_STORES",
  "funding_type": "SHARED",
  "brand_share": 60,
  "store_share": 40,
  "store_ids": [
    "92000000-0000-0000-0000-000000000005",
    "92000000-0000-0000-0000-000000000006"
  ]
}''', "discount_type: PERCENTAGE hoặc FIXED_AMOUNT; scope: ALL_STORES hoặc SELECTED_STORES; funding_type: BRAND, STORE hoặc SHARED. Hai tỷ lệ góp phải có tổng 100."),
        api("GET", "/promotions?status=ACTIVE&search=Trung thu&page=1&page_size=20", "Xem danh sách khuyến mãi và lọc theo trạng thái/tên.", "Người dùng đã đăng nhập", "Query mẫu: status=ACTIVE, search=Trung thu, page=1, page_size=20."),
        api("POST", "/promotions/{promotion_id}/activate", "Bật một chương trình khuyến mãi nháp.", "Admin", "Không có request body.", "Thay {promotion_id} bằng UUID chương trình ở trạng thái DRAFT."),
        api("POST", "/promotions/{promotion_id}/cancel", "Hủy chương trình khuyến mãi.", "Admin", '''{
  "reason": "Điều chỉnh kế hoạch marketing tháng này."
}''', "Lý do bắt buộc; thành công trả 204."),
        api("DELETE", "/promotions/{promotion_id}", "Xóa mềm chương trình không còn hoạt động.", "Admin", '''{
  "reason": "Tạo nhầm chương trình, chưa phát sinh giao dịch."
}''', "Không thể xóa chương trình đang ACTIVE. Dữ liệu được đánh dấu xóa mềm."),
    ],
    "Doanh thu": [
        api("POST", "/revenues", "Tạo báo cáo doanh thu cho một cửa hàng và ngày kinh doanh.", "Chủ cửa hàng được phân quyền cửa hàng", '''{
  "store_id": "92000000-0000-0000-0000-000000000001",
  "business_date": "2026-09-28",
  "gross_revenue": 12850000,
  "note": "Doanh thu đã đối chiếu với báo cáo chốt ca.",
  "promotion_details": [
    {
      "promotion_id": "94000000-0000-0000-0000-000000000001",
      "discount_amount": 450000
    }
  ]
}''', "gross_revenue và discount_amount tính bằng VND. promotion_details có thể là []. Mỗi cửa hàng chỉ có một báo cáo cho một ngày."),
        api("PUT", "/revenues/{revenue_id}", "Cập nhật báo cáo doanh thu còn ở trạng thái cho phép chỉnh sửa.", "Chủ cửa hàng được phân quyền cửa hàng", '''{
  "store_id": "92000000-0000-0000-0000-000000000001",
  "business_date": "2026-09-28",
  "gross_revenue": 12920000,
  "note": "Cập nhật sau khi bổ sung đơn giao hàng.",
  "promotion_details": []
}''', "Thay {revenue_id} bằng ID bản ghi; gửi lại các trường cần thiết theo mẫu."),
        api("GET", "/revenues?status=SUBMITTED&page=1&page_size=20", "Xem báo cáo doanh thu theo quyền cửa hàng và trạng thái.", "Người dùng đã đăng nhập", "Query mẫu: status=SUBMITTED, page=1, page_size=20."),
        api("POST", "/revenues/{revenue_id}/submit", "Gửi báo cáo doanh thu để kế toán xét duyệt.", "Chủ cửa hàng được phân quyền cửa hàng", "Không có request body.", "ID lấy từ kết quả tạo/lấy danh sách doanh thu; thành công trả 204."),
        api("POST", "/revenues/{revenue_id}/approve", "Duyệt báo cáo doanh thu hợp lệ.", "Kế toán", '''{
  "note": "Đã khớp doanh thu với bảng kê bán hàng."
}''', "note có thể để null. Duyệt doanh thu là một phần của đối soát định kỳ."),
        api("POST", "/revenues/{revenue_id}/reject", "Từ chối báo cáo sai lệch để cửa hàng kiểm tra lại.", "Kế toán", '''{
  "reason": "Tổng doanh thu chưa khớp với báo cáo chốt ca ngày 28/09."
}''', "Lý do bắt buộc."),
        api("POST", "/revenues/{revenue_id}/request-adjustment", "Yêu cầu cửa hàng bổ sung hoặc điều chỉnh số liệu.", "Kế toán", '''{
  "reason": "Vui lòng bổ sung doanh thu từ đơn hàng giao qua ứng dụng."
}''', "Lý do bắt buộc; trạng thái chuyển sang ADJUSTMENT_REQUESTED."),
    ],
    "Điều chỉnh phí và hóa đơn": [
        api("POST", "/billing-adjustments?store_id=92000000-0000-0000-0000-000000000001", "Tạo khoản cộng/trừ phí vào kỳ thanh toán cửa hàng.", "Kế toán", '''{
  "source_period": "2026-08-01",
  "amount": -250000,
  "reason": "Điều chỉnh phần hỗ trợ khuyến mãi đã ghi nhận thừa."
}''', "store_id là query parameter. amount khác 0; số dương cộng phí, số âm giảm phí. source_period là ngày đầu tháng hoặc null."),
        api("POST", "/invoices/generate", "Tính và tạo hóa đơn phí theo doanh thu tháng đã chốt.", "Kế toán", '''{
  "store_id": "92000000-0000-0000-0000-000000000001",
  "invoice_no": "INV-202609-HN-HK-001-01",
  "period_month": "2026-09-01",
  "vat_rate": 10
}''', "period_month dùng ngày đầu tháng. Hệ thống lấy dữ liệu chốt tháng và hợp đồng để tính tiền; mỗi cửa hàng chỉ có một hóa đơn hiện hành mỗi kỳ."),
        api("GET", "/invoices?status=OVERDUE&search=INV-202608&page=1&page_size=20", "Tra cứu hóa đơn theo trạng thái hoặc mã hóa đơn.", "Người dùng đã đăng nhập", "Query mẫu: status=OVERDUE, search=INV-202608, page=1, page_size=20."),
        api("POST", "/invoices/{invoice_id}/issue", "Phát hành hóa đơn nháp cho cửa hàng.", "Kế toán", "Không có request body.", "Thay {invoice_id} bằng UUID hóa đơn DRAFT."),
        api("POST", "/invoices/{invoice_id}/cancel", "Hủy hóa đơn và ghi lại lý do.", "Kế toán", '''{
  "reason": "Hóa đơn được lập sai kỳ doanh thu, sẽ phát hành lại."
}''', "Lý do bắt buộc; kiểm tra quy tắc trạng thái trước khi thực hiện."),
        api("POST", "/invoices/{invoice_id}/payments", "Ghi nhận một giao dịch thanh toán cho hóa đơn.", "Kế toán", '''{
  "payment_no": "PAY-202609-HN-HK-001-01",
  "amount": 12500000,
  "payment_date": "2026-09-28",
  "method": "BANK_TRANSFER",
  "reference_no": "VCB260928091234"
}''', "method nhận BANK_TRANSFER, CASH hoặc OTHER. amount phải lớn hơn 0 và không vượt outstanding_amount của hóa đơn."),
    ],
    "Thanh toán": [
        api("GET", "/payments?status=CONFIRMED&search=PAY-202608&page=1&page_size=20", "Tra cứu giao dịch thanh toán.", "Người dùng đã đăng nhập", "Query mẫu: status=CONFIRMED, search=PAY-202608, page=1, page_size=20."),
        api("POST", "/payments/{payment_id}/reverse", "Đảo một khoản thanh toán đã ghi nhận nhầm.", "Kế toán", '''{
  "reason": "Giao dịch được nhập trùng, đã xác minh với sao kê ngân hàng."
}''', "Lý do bắt buộc; đảo thanh toán làm cập nhật số đã trả và công nợ hóa đơn."),
    ],
    "Thông báo, vận hành và báo cáo": [
        api("GET", "/notifications?page=1&page_size=20", "Lấy danh sách thông báo của tài khoản hiện tại.", "Người dùng đã đăng nhập", "Query mẫu: page=1, page_size=20."),
        api("PATCH", "/notifications/{notification_id}/read", "Đánh dấu thông báo đã đọc.", "Chủ sở hữu thông báo", "Không có request body.", "Thay {notification_id} bằng UUID thông báo của chính tài khoản."),
        api("POST", "/operations/generate-alerts", "Tạo cảnh báo cho các cửa hàng chậm báo cáo doanh thu.", "Admin", "Không có request body.", "Thành công trả 204; gọi lại an toàn theo cơ chế chống cảnh báo trùng."),
        api("GET", "/audit-logs?search=APPROVE&page=1&page_size=20", "Tra cứu lịch sử thao tác và đối tượng đã thay đổi.", "Admin", "Query mẫu: search=APPROVE, page=1, page_size=20.", "Audit log lưu người thực hiện, hành động, thời điểm và dữ liệu liên quan."),
        api("GET", "/reports/financial-summary?period_from=2026-09-01&period_to=2026-09-30", "Tổng hợp chỉ số tài chính trong khoảng ngày.", "Người dùng đã đăng nhập", "Query bắt buộc: period_from=2026-09-01, period_to=2026-09-30.", "Chỉ trả dữ liệu cửa hàng người dùng có quyền xem."),
    ],
}


EXPORTS = [
    api("GET", "/contracts/{contract_id}/pdf", "Tải hợp đồng cửa hàng dưới dạng PDF.", "Người dùng có quyền xem cửa hàng", "Path: contract_id={UUID hợp đồng}.", "Phản hồi là file application/pdf."),
    api("GET", "/invoices/{invoice_id}/pdf", "Tải hóa đơn phí franchise dưới dạng PDF.", "Người dùng có quyền xem cửa hàng", "Path: invoice_id={UUID hóa đơn}.", "Phản hồi là file application/pdf."),
    api("GET", "/reports/financial-summary/export?period_from=2026-09-01&period_to=2026-09-30&format=xlsx", "Tải báo cáo tài chính dạng CSV hoặc Excel.", "Người dùng đã đăng nhập", "Query: period_from=2026-09-01, period_to=2026-09-30, format=xlsx. Đổi format thành csv nếu cần.", "Phản hồi là file tải xuống, không phải JSON."),
    api("POST", "/revenues/import", "Nhập nhiều báo cáo doanh thu từ CSV hoặc XLSX.", "Người dùng được phân quyền các cửa hàng trong file", "Multipart form-data: field file = file .csv hoặc .xlsx. CSV cần header store_id,business_date,gross_revenue,note; ví dụ: 92000000-0000-0000-0000-000000000001,2026-09-28,12850000,Doanh thu đã đối soát.", "File tối đa 10 MB và 5.000 dòng. Mỗi dòng nhập độc lập; phản hồi nêu số dòng thành công và lỗi."),
]


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shading = OxmlElement("w:shd")
    shading.set(qn("w:fill"), fill)
    tc_pr.append(shading)


def set_cell_margins(cell, top=90, start=110, bottom=90, end=110):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    margins = tc_pr.first_child_found_in("w:tcMar")
    if margins is None:
        margins = OxmlElement("w:tcMar")
        tc_pr.append(margins)
    for edge, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = margins.find(qn(f"w:{edge}"))
        if node is None:
            node = OxmlElement(f"w:{edge}")
            margins.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_font(run, name="Arial", size=10, bold=None, color="000000"):
    run.font.name = name
    run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), name)
    run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), name)
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), name)
    run.font.size = Pt(size)
    run.font.color.rgb = RGBColor.from_string(color)
    if bold is not None:
        run.bold = bold


def add_label(doc, label, value):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(1)
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.keep_together = True
    r = p.add_run(f"{label}: ")
    set_font(r, size=9, bold=True)
    r = p.add_run(value)
    set_font(r, size=9)


def add_code(doc, sample):
    p = doc.add_paragraph()
    p.style = doc.styles["Normal"]
    p.paragraph_format.left_indent = Inches(0.12)
    p.paragraph_format.right_indent = Inches(0.08)
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(8)
    p.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
    p.paragraph_format.keep_together = True
    p_pr = p._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), "F2F4F7")
    p_pr.append(shd)
    for index, line in enumerate(sample.splitlines()):
        if index:
            p.add_run().add_break()
        r = p.add_run(line if line else " ")
        set_font(r, name="Consolas", size=8, color="243247")


def add_api(doc, item, index):
    heading = doc.add_heading(level=2)
    heading.paragraph_format.keep_with_next = True
    r = heading.add_run(f"{index:02d}. {item['method']}  {item['path']}")
    set_font(r, size=12, bold=True, color="000000")
    add_label(doc, "Mục đích", item["purpose"])
    add_label(doc, "Quyền", item["role"])
    add_label(doc, "Input mẫu", item["sample"])
    if item["sample"].lstrip().startswith("{"):
        add_code(doc, item["sample"])
    if item["note"]:
        add_label(doc, "Lưu ý", item["note"])


def add_page_number(paragraph):
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = paragraph.add_run("Trang ")
    set_font(run, size=8, color="5E6B78")
    field = OxmlElement("w:fldSimple")
    field.set(qn("w:instr"), "PAGE")
    paragraph._p.append(field)


def create_document():
    doc = Document()
    section = doc.sections[0]
    section.page_width = Inches(8.27)
    section.page_height = Inches(11.69)
    section.top_margin = Inches(0.68)
    section.bottom_margin = Inches(0.68)
    section.left_margin = Inches(0.78)
    section.right_margin = Inches(0.78)
    section.header_distance = Inches(0.3)
    section.footer_distance = Inches(0.35)

    normal = doc.styles["Normal"]
    normal.font.name = "Arial"
    normal._element.rPr.rFonts.set(qn("w:ascii"), "Arial")
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Arial")
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Arial")
    normal.font.size = Pt(9.5)
    normal.paragraph_format.space_after = Pt(5)
    normal.paragraph_format.line_spacing = 1.08

    for style_name, size in (("Title", 25), ("Heading 1", 17), ("Heading 2", 12)):
        style = doc.styles[style_name]
        style.font.name = "Arial"
        style._element.rPr.rFonts.set(qn("w:ascii"), "Arial")
        style._element.rPr.rFonts.set(qn("w:hAnsi"), "Arial")
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "Arial")
        style.font.size = Pt(size)
        style.font.color.rgb = RGBColor(0, 0, 0)
        style.font.bold = style_name != "Title"
    doc.styles["Heading 1"].paragraph_format.space_before = Pt(14)
    doc.styles["Heading 1"].paragraph_format.space_after = Pt(6)
    doc.styles["Heading 1"].paragraph_format.keep_with_next = True
    doc.styles["Heading 2"].paragraph_format.space_before = Pt(9)
    doc.styles["Heading 2"].paragraph_format.space_after = Pt(3)

    title = doc.add_paragraph(style="Title")
    title.paragraph_format.space_after = Pt(3)
    run = title.add_run("Hướng dẫn API nghiệp vụ Franchise")
    set_font(run, size=25, color="000000")
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(12)
    run = p.add_run("Mô tả endpoint và dữ liệu mẫu dùng với Swagger")
    set_font(run, size=12, color="465568")

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(7)
    r = p.add_run(
        "Tài liệu này hướng dẫn các API trong nhóm Business của Franchise Management API. "
        "Mỗi mục nêu mục đích, vai trò được phép và input mẫu theo cấu trúc request của dự án. "
        "Các dữ liệu ví dụ dùng tên cửa hàng, địa chỉ và giao dịch tại Việt Nam."
    )
    set_font(r, size=10)

    doc.add_heading("Cách dùng trong Swagger", level=1)
    steps = [
        "Mở http://localhost:8000/docs và bấm Authorize. Dùng tài khoản admin@franchise.local / Admin@123; nhập email ở ô username, để trống client_id và client_secret.",
        "Mở API cần gọi, bấm Try it out, điền path parameter, query parameter hoặc request body theo ví dụ, rồi bấm Execute.",
        "Với API tạo dữ liệu, lưu trường id trong phản hồi để dùng cho các bước tiếp theo. Với endpoint có {application_id}, {store_id}, {contract_id}, {revenue_id}, {invoice_id}, {payment_id} hoặc {notification_id}, thay phần trong ngoặc bằng UUID thật từ phản hồi/danh sách.",
        "Các API tạo mới thường trả 201 và JSON có id; các thao tác thành công không trả nội dung thường trả 204; API GET thường trả 200.",
    ]
    for text in steps:
        p = doc.add_paragraph(style="List Number")
        p.paragraph_format.space_after = Pt(4)
        r = p.add_run(text)
        set_font(r, size=9.5)

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run("Lưu ý dữ liệu: ")
    set_font(r, size=9.5, bold=True)
    r = p.add_run(
        "POST, PUT, PATCH và DELETE có thể thay đổi database local. Không chạy lại thao tác tạo cho cùng cửa hàng/ngày hoặc cùng kỳ hóa đơn nếu dữ liệu đó đã tồn tại."
    )
    set_font(r, size=9.5)

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(7)
    r = p.add_run("Base path API: ")
    set_font(r, size=9.5, bold=True)
    r = p.add_run("http://localhost:8000/api/v1")
    set_font(r, name="Consolas", size=9, color="243247")
    r = p.add_run(". Ghép base path với route trong tiêu đề từng API.")
    set_font(r, size=9.5)

    doc.add_heading("Quy ước input", level=1)
    p = doc.add_paragraph(
        "Các ngày dùng định dạng YYYY-MM-DD; số tiền tính bằng VND; phần trăm nhập dạng số, ví dụ 5 nghĩa là 5%. "
        "Danh sách GET dùng page và page_size; một số danh sách hỗ trợ search và status. "
        "Nếu mẫu có ghi không có request body, để phần Body trống trong Swagger. "
        "Khi tạo hồ sơ, email trong request nên trùng tài khoản đang đăng nhập để thông tin chủ hồ sơ nhất quán."
    )
    p.paragraph_format.space_after = Pt(7)

    index = 1
    for group, items in BUSINESS.items():
        doc.add_heading(group, level=1)
        for item in items:
            add_api(doc, item, index)
            index += 1

    doc.add_page_break()
    doc.add_heading("API nhập xuất liên quan", level=1)
    p = doc.add_paragraph(
        "Các endpoint này xuất hiện ở nhóm Import and Export trong Swagger, tách khỏi tag Business, "
        "nhưng phục vụ trực tiếp báo cáo và chứng từ nghiệp vụ."
    )
    p.paragraph_format.space_after = Pt(6)
    for item in EXPORTS:
        add_api(doc, item, index)
        index += 1

    doc.add_heading("Mã phản hồi thường gặp", level=1)
    responses = [
        ("200 OK", "Đọc dữ liệu hoặc thao tác trả về kết quả."),
        ("201 Created", "Tạo mới thành công; response thường có id bản ghi."),
        ("204 No Content", "Thao tác thành công, không có JSON response body."),
        ("401 Unauthorized", "Chưa đăng nhập hoặc access token không hợp lệ/hết hạn."),
        ("403 Forbidden", "Đã đăng nhập nhưng tài khoản không có vai trò hoặc quyền với dữ liệu."),
        ("404 Not Found", "Không tìm thấy bản ghi theo UUID hoặc bản ghi không thuộc phạm vi truy cập."),
        ("422 Unprocessable Entity", "Input sai định dạng, thiếu trường bắt buộc hoặc không hợp lệ."),
        ("409 Conflict", "Trạng thái nghiệp vụ không cho phép hoặc dữ liệu bị trùng, ví dụ doanh thu cùng cửa hàng/ngày."),
    ]
    table = doc.add_table(rows=1, cols=2)
    table.autofit = False
    table.columns[0].width = Inches(1.55)
    table.columns[1].width = Inches(5.15)
    header = table.rows[0].cells
    header[0].text = "Mã"
    header[1].text = "Ý nghĩa"
    for cell in header:
        set_cell_shading(cell, "274C77")
        set_cell_margins(cell)
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        for run in cell.paragraphs[0].runs:
            set_font(run, size=9, bold=True, color="FFFFFF")
    for code, meaning in responses:
        cells = table.add_row().cells
        cells[0].text = code
        cells[1].text = meaning
        for cell in cells:
            set_cell_margins(cell)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            for paragraph in cell.paragraphs:
                paragraph.paragraph_format.space_after = Pt(1)
                for run in paragraph.runs:
                    set_font(run, size=8.5)
    for row in table.rows:
        row.cells[0].width = Inches(1.55)
        row.cells[1].width = Inches(5.15)

    footer = section.footer.paragraphs[0]
    add_page_number(footer)
    doc.core_properties.title = "Hướng dẫn API nghiệp vụ Franchise"
    doc.core_properties.subject = "Mô tả và input mẫu cho Business API"
    doc.core_properties.author = "Franchise Management Project"
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUTPUT)
    print(f"Created {OUTPUT}")
    print(f"Business endpoints: {index - 1 - len(EXPORTS)}; related import/export endpoints: {len(EXPORTS)}")


if __name__ == "__main__":
    create_document()
