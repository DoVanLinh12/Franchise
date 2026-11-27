"""Printable documents (contract, fee statement) and spreadsheet exports.

PDFs use the bundled DejaVu fonts so Vietnamese text renders correctly.
"""

from __future__ import annotations

import csv
from datetime import date, datetime
from decimal import Decimal
from io import BytesIO, StringIO
from pathlib import Path
from typing import Any

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    KeepTogether,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

# --------------------------------------------------------------------------- brand
BRAND = {
    "name": "CÔNG TY CỔ PHẦN MỘC MIÊN COFFEE",
    "short": "Mộc Miên Coffee",
    "address": "Tầng 8, 72 Trần Hưng Đạo, phường Trần Hưng Đạo, quận Hoàn Kiếm, Hà Nội",
    "phone": "024 3933 6868",
    "email": "nhuongquyen@mocmien.vn",
    "representative": "Ông Nguyễn Hoàng Nam",
    "position": "Giám đốc Vận hành chuỗi",
    "bank": "Ngân hàng TMCP Ngoại thương Việt Nam (Vietcombank) - CN Hà Nội",
    "account_name": "CONG TY CO PHAN MOC MIEN COFFEE",
}

# --------------------------------------------------------------------------- fonts
FONT_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"
_FONTS_READY = False


def _register_fonts() -> None:
    global _FONTS_READY
    if _FONTS_READY:
        return
    pdfmetrics.registerFont(TTFont("DejaVu", str(FONT_DIR / "DejaVuSans.ttf")))
    pdfmetrics.registerFont(TTFont("DejaVu-Bold", str(FONT_DIR / "DejaVuSans-Bold.ttf")))
    pdfmetrics.registerFont(TTFont("DejaVu-Italic", str(FONT_DIR / "DejaVuSans-Oblique.ttf")))
    pdfmetrics.registerFontFamily(
        "DejaVu", normal="DejaVu", bold="DejaVu-Bold", italic="DejaVu-Italic",
        boldItalic="DejaVu-Bold",
    )
    _FONTS_READY = True


def _styles() -> dict[str, ParagraphStyle]:
    _register_fonts()
    base = ParagraphStyle("base", fontName="DejaVu", fontSize=9.5, leading=13.5)
    return {
        "base": base,
        "justify": ParagraphStyle("justify", parent=base, alignment=TA_JUSTIFY),
        "center": ParagraphStyle("center", parent=base, alignment=TA_CENTER),
        "right": ParagraphStyle("right", parent=base, alignment=TA_RIGHT),
        "small": ParagraphStyle("small", parent=base, fontSize=8, leading=10.5,
                                textColor=colors.HexColor("#555555")),
        "nation": ParagraphStyle("nation", parent=base, fontName="DejaVu-Bold",
                                 alignment=TA_CENTER, fontSize=10.5),
        "motto": ParagraphStyle("motto", parent=base, fontName="DejaVu-Bold",
                                alignment=TA_CENTER, fontSize=10),
        "title": ParagraphStyle("title", parent=base, fontName="DejaVu-Bold",
                                alignment=TA_CENTER, fontSize=15, leading=20,
                                spaceBefore=6, spaceAfter=2),
        "subtitle": ParagraphStyle("subtitle", parent=base, alignment=TA_CENTER,
                                   fontName="DejaVu-Italic"),
        "heading": ParagraphStyle("heading", parent=base, fontName="DejaVu-Bold",
                                  fontSize=10, spaceBefore=7, spaceAfter=2),
        "cell": ParagraphStyle("cell", parent=base, fontSize=9, leading=12),
        "cell_bold": ParagraphStyle("cell_bold", parent=base, fontName="DejaVu-Bold",
                                    fontSize=9, leading=12),
        "cell_right": ParagraphStyle("cell_right", parent=base, fontSize=9, leading=12,
                                     alignment=TA_RIGHT),
        "cell_right_bold": ParagraphStyle("cell_right_bold", parent=base,
                                          fontName="DejaVu-Bold", fontSize=9,
                                          leading=12, alignment=TA_RIGHT),
    }


# --------------------------------------------------------------------------- formatting
def _num(value: Any) -> Decimal:
    if value in (None, ""):
        return Decimal(0)
    return Decimal(str(value))


def money(value: Any) -> str:
    return f"{_num(value):,.0f}".replace(",", ".")


def pct(value: Any) -> str:
    """5.0000 -> '5', 5.5000 -> '5,5' (Vietnamese decimal comma)."""
    text = format(_num(value).normalize(), "f")
    return text.replace(".", ",")


def vn_date(value: Any) -> str:
    if not value:
        return "—"
    if isinstance(value, (date, datetime)):
        parsed = value
    else:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    return parsed.strftime("%d/%m/%Y")


def _long_date(value: Any) -> str:
    if not value:
        return "ngày ... tháng ... năm ......"
    parsed = value if isinstance(value, date) else datetime.fromisoformat(str(value)).date()
    return f"ngày {parsed.day:02d} tháng {parsed.month:02d} năm {parsed.year}"


_DIGITS = ["không", "một", "hai", "ba", "bốn", "năm", "sáu", "bảy", "tám", "chín"]
_UNITS = ["", " nghìn", " triệu", " tỷ", " nghìn tỷ", " triệu tỷ"]


def _read_triple(n: int, full: bool) -> str:
    hundreds, rest = divmod(n, 100)
    tens, ones = divmod(rest, 10)
    parts: list[str] = []
    if full or hundreds:
        parts.append(f"{_DIGITS[hundreds]} trăm")
    if tens > 1:
        parts.append(f"{_DIGITS[tens]} mươi")
        if ones == 1:
            parts.append("mốt")
        elif ones == 4:
            parts.append("tư")
        elif ones == 5:
            parts.append("lăm")
        elif ones:
            parts.append(_DIGITS[ones])
    elif tens == 1:
        parts.append("mười")
        if ones == 5:
            parts.append("lăm")
        elif ones:
            parts.append(_DIGITS[ones])
    elif ones:
        if full or hundreds:
            parts.append("lẻ")
        parts.append(_DIGITS[ones])
    return " ".join(parts)


def amount_in_words(value: Any) -> str:
    """Read a VND amount in Vietnamese, e.g. 1.250.000 -> 'Một triệu hai trăm năm mươi nghìn đồng'."""
    amount = int(_num(value))
    if amount == 0:
        return "Không đồng"
    groups: list[int] = []
    while amount:
        amount, group = divmod(amount, 1000)
        groups.append(group)
    words: list[str] = []
    for index in range(len(groups) - 1, -1, -1):
        group = groups[index]
        if group == 0:
            continue
        full = index < len(groups) - 1
        words.append(_read_triple(group, full) + _UNITS[index])
    text = " ".join(words).strip()
    return text[0].upper() + text[1:] + " đồng"


def _grid(data: list[list[Any]], widths: list[float], header: bool = True,
          zebra: bool = False) -> Table:
    table = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    style: list[Any] = [
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#9AA5B1")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]
    if header:
        style.append(("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#DCE6F1")))
    if zebra:
        for row in range(1 + int(header), len(data), 2):
            style.append(("BACKGROUND", (0, row), (-1, row), colors.HexColor("#F7F9FB")))
    table.setStyle(TableStyle(style))
    return table


def _build(story: list[Any], title: str, watermark: str | None = None) -> bytes:
    output = BytesIO()

    def decorate(canvas: Any, doc: Any) -> None:
        canvas.saveState()
        canvas.setFont("DejaVu", 7.5)
        canvas.setFillColor(colors.HexColor("#777777"))
        canvas.drawString(18 * mm, 10 * mm, f"{BRAND['short']} - {title}")
        canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"Trang {doc.page}")
        if watermark:
            canvas.setFont("DejaVu-Bold", 60)
            canvas.setFillColor(colors.Color(0.85, 0.2, 0.2, alpha=0.12))
            canvas.translate(A4[0] / 2, A4[1] / 2)
            canvas.rotate(35)
            canvas.drawCentredString(0, 0, watermark)
        canvas.restoreState()

    document = SimpleDocTemplate(
        output, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
        topMargin=15 * mm, bottomMargin=18 * mm, title=title, author=BRAND["name"],
    )
    document.build(story, onFirstPage=decorate, onLaterPages=decorate)
    return output.getvalue()


def _signatures(left: str, left_name: str, right: str, right_name: str,
                styles: dict[str, ParagraphStyle]) -> Table:
    sign = styles["center"]
    block = Table(
        [[Paragraph(f"<b>{left}</b>", sign), Paragraph(f"<b>{right}</b>", sign)],
         [Paragraph("<i>(Ký, ghi rõ họ tên, đóng dấu)</i>", sign),
          Paragraph("<i>(Ký, ghi rõ họ tên)</i>", sign)],
         [Spacer(1, 16 * mm), Spacer(1, 16 * mm)],
         [Paragraph(f"<b>{left_name}</b>", sign), Paragraph(f"<b>{right_name}</b>", sign)]],
        colWidths=[87 * mm, 87 * mm],
    )
    block.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
    return block


# --------------------------------------------------------------------------- contract
def contract_pdf(contract: dict[str, Any]) -> bytes:
    s = _styles()
    status = contract.get("status")
    signed = contract.get("signed_date")
    store = f"{contract.get('store_name') or ''} (mã {contract.get('store_code') or '—'})"
    royalty = _num(contract.get("royalty_rate"))
    initial_fee = _num(contract.get("initial_franchise_fee"))
    story: list[Any] = [
        Paragraph("CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM", s["nation"]),
        Paragraph("Độc lập - Tự do - Hạnh phúc", s["motto"]),
        Paragraph("―――――――――――", s["center"]),
        Paragraph("HỢP ĐỒNG NHƯỢNG QUYỀN THƯƠNG MẠI", s["title"]),
        Paragraph(f"Số: {contract.get('contract_no') or '—'}", s["subtitle"]),
        Spacer(1, 4 * mm),
        Paragraph("<i>- Căn cứ Luật Thương mại số 36/2005/QH11 và Nghị định 35/2006/NĐ-CP quy định chi tiết "
                  "về hoạt động nhượng quyền thương mại;</i>", s["justify"]),
        Paragraph("<i>- Căn cứ nhu cầu và khả năng của hai bên.</i>", s["justify"]),
        Spacer(1, 2 * mm),
        Paragraph(f"Hôm nay, {_long_date(signed)}, tại Hà Nội, chúng tôi gồm:", s["justify"]),
        Paragraph("BÊN NHƯỢNG QUYỀN (Bên A)", s["heading"]),
        _grid([
            [Paragraph("Tên doanh nghiệp", s["cell"]), Paragraph(f"<b>{BRAND['name']}</b>", s["cell"])],
            [Paragraph("Địa chỉ", s["cell"]), Paragraph(BRAND["address"], s["cell"])],
            [Paragraph("Điện thoại / Email", s["cell"]), Paragraph(f"{BRAND['phone']} / {BRAND['email']}", s["cell"])],
            [Paragraph("Người đại diện", s["cell"]), Paragraph(f"{BRAND['representative']} - {BRAND['position']}", s["cell"])],
        ], [45 * mm, 129 * mm], header=False),
        Paragraph("BÊN NHẬN QUYỀN (Bên B)", s["heading"]),
        _grid([
            [Paragraph("Họ và tên", s["cell"]), Paragraph(f"<b>{contract.get('owner_name') or '—'}</b>", s["cell"])],
            [Paragraph("Điện thoại / Email", s["cell"]),
             Paragraph(f"{contract.get('owner_phone') or '—'} / {contract.get('owner_email') or '—'}", s["cell"])],
            [Paragraph("Cửa hàng nhận quyền", s["cell"]), Paragraph(store, s["cell"])],
            [Paragraph("Địa điểm kinh doanh", s["cell"]), Paragraph(contract.get("store_address") or "—", s["cell"])],
        ], [45 * mm, 129 * mm], header=False),
        Spacer(1, 2 * mm),
        Paragraph("Hai bên thống nhất ký kết hợp đồng nhượng quyền thương mại với các điều khoản sau:", s["justify"]),
        Paragraph("Điều 1. Đối tượng hợp đồng", s["heading"]),
        Paragraph(f"Bên A cấp cho Bên B quyền kinh doanh đồ uống và bánh dưới thương hiệu \"{BRAND['short']}\" "
                  f"theo mô hình, công thức, bộ nhận diện và hệ thống quản lý của Bên A tại địa điểm nêu trên, "
                  f"với tên cửa hàng {store}.", s["justify"]),
        Paragraph("Điều 2. Thời hạn hợp đồng", s["heading"]),
        Paragraph(f"Hợp đồng có hiệu lực từ ngày {vn_date(contract.get('effective_from'))} đến ngày "
                  f"{vn_date(contract.get('effective_to'))}. Cửa hàng được tạo trên hệ thống khi hợp đồng được lập "
                  f"và chính thức hoạt động khi Bên B đã thanh toán tối thiểu 20% phí nhượng quyền ban đầu.", s["justify"]),
        Paragraph("Điều 3. Phí nhượng quyền và phương thức thanh toán", s["heading"]),
        _grid([
            [Paragraph("<b>Khoản phí</b>", s["cell"]), Paragraph("<b>Mức phí</b>", s["cell_right"]),
             Paragraph("<b>Thời điểm thanh toán</b>", s["cell"])],
            [Paragraph("Phí nhượng quyền ban đầu", s["cell"]), Paragraph(f"{money(initial_fee)} đ", s["cell_right"]),
             Paragraph(f"Tối thiểu 20% ({money((initial_fee * Decimal('0.2')).to_integral_value())} đ) trước khi khai trương", s["cell"])],
            [Paragraph("Tiền ký quỹ bảo đảm", s["cell"]), Paragraph(f"{money(contract.get('deposit_amount'))} đ", s["cell_right"]),
             Paragraph("Khi ký hợp đồng; hoàn trả khi thanh lý", s["cell"])],
            [Paragraph("Phí bản quyền (royalty)", s["cell"]), Paragraph(f"{pct(royalty)}% doanh thu gộp", s["cell_right"]),
             Paragraph("Hằng tháng, theo thông báo phí", s["cell"])],
            [Paragraph("Phí hệ thống", s["cell"]), Paragraph(f"{money(contract.get('system_fee'))} đ/tháng", s["cell_right"]),
             Paragraph("Hằng tháng, theo thông báo phí", s["cell"])],
            [Paragraph("Phí dịch vụ vận hành, marketing", s["cell"]), Paragraph(f"{money(contract.get('service_fee'))} đ/tháng", s["cell_right"]),
             Paragraph("Hằng tháng, theo thông báo phí", s["cell"])],
        ], [62 * mm, 45 * mm, 67 * mm]),
        Spacer(1, 1.5 * mm),
        Paragraph("Các khoản phí hằng tháng chưa bao gồm thuế GTGT 10%. Bên A phát hành thông báo phí vào đầu tháng kế tiếp; "
                  "Bên B thanh toán bằng chuyển khoản trong vòng 07 ngày kể từ ngày phát hành.", s["justify"]),
        Paragraph("Điều 4. Chương trình khuyến mãi", s["heading"]),
        Paragraph("Bên A chịu 100% chi phí các chương trình khuyến mãi do Bên A phát động. Toàn bộ số tiền giảm giá đã được "
                  "duyệt trên doanh thu của Bên B được khấu trừ vào thông báo phí của tháng tương ứng.", s["justify"]),
        Paragraph("Điều 5. Báo cáo doanh thu", s["heading"]),
        Paragraph("Bên B báo cáo doanh thu từng ngày trên hệ thống quản lý của Bên A chậm nhất 23 giờ ngày hôm sau. "
                  "Phí bản quyền được tính trên doanh thu gộp (trước giảm giá) đã được bộ phận kế toán của Bên A duyệt.", s["justify"]),
        Paragraph("Điều 6. Quyền và nghĩa vụ của các bên", s["heading"]),
        Paragraph("6.1. Bên A: chuyển giao công thức, đào tạo nhân sự, cung cấp hệ thống quản lý và hỗ trợ marketing; "
                  "kiểm tra việc tuân thủ tiêu chuẩn thương hiệu.", s["justify"]),
        Paragraph("6.2. Bên B: vận hành cửa hàng theo tiêu chuẩn của Bên A; báo cáo doanh thu trung thực, đúng hạn; "
                  "thanh toán đầy đủ các khoản phí; bảo mật bí quyết kinh doanh.", s["justify"]),
        Paragraph("Điều 7. Điều khoản chung", s["heading"]),
        Paragraph("Hai bên cam kết thực hiện đúng các điều khoản. Tranh chấp phát sinh được giải quyết bằng thương lượng; "
                  "nếu không thành sẽ đưa ra Tòa án có thẩm quyền. Hợp đồng lập thành 02 bản có giá trị pháp lý như nhau, "
                  "mỗi bên giữ 01 bản.", s["justify"]),
        Spacer(1, 6 * mm),
        KeepTogether(_signatures("ĐẠI DIỆN BÊN A", BRAND["representative"].replace("Ông ", ""),
                                 "ĐẠI DIỆN BÊN B", contract.get("owner_name") or "", s)),
    ]
    if status == "ACTIVE":
        paid = (f"Tình trạng: Hợp đồng đang hiệu lực. Đã thu phí ban đầu {money(contract.get('initial_fee_paid'))} đ, "
                f"tiền ký quỹ {money(contract.get('deposit_paid'))} đ.")
        story.insert(5, Paragraph(paid, s["small"]))
    watermark = "BẢN NHÁP" if status == "DRAFT" else None
    return _build(story, f"Hợp đồng {contract.get('contract_no') or ''}", watermark)


# --------------------------------------------------------------------------- fee statement
_INVOICE_STATUS = {
    "DRAFT": "BẢN NHÁP", "ISSUED": "CHỜ THANH TOÁN", "PARTIALLY_PAID": "THANH TOÁN MỘT PHẦN",
    "PAID": "ĐÃ THANH TOÁN", "OVERDUE": "QUÁ HẠN", "CANCELLED": "ĐÃ HỦY",
}
_METHODS = {"BANK_TRANSFER": "Chuyển khoản", "CASH": "Tiền mặt", "OTHER": "Khác"}


def invoice_pdf(invoice: dict[str, Any]) -> bytes:
    s = _styles()
    period = invoice.get("period_month")
    period_text = "—"
    if period:
        parsed = period if isinstance(period, date) else date.fromisoformat(str(period)[:10])
        period_text = f"{parsed.month:02d}/{parsed.year}"
    royalty_rate = _num(invoice.get("royalty_rate"))
    adjustments = _num(invoice.get("positive_adjustments")) - _num(invoice.get("negative_adjustments"))
    rows = [
        ["1", "Doanh thu gộp đã duyệt trong tháng", "Căn cứ", money(invoice.get("monthly_gross_revenue"))],
        ["2", f"Phí bản quyền ({pct(royalty_rate)}% × doanh thu gộp)", "Cộng", money(invoice.get("royalty_fee"))],
        ["3", "Phí hệ thống", "Cộng", money(invoice.get("system_fee"))],
        ["4", "Phí dịch vụ vận hành, marketing", "Cộng", money(invoice.get("service_fee"))],
        ["5", "Điều chỉnh phí trong kỳ", "Cộng/Trừ", money(adjustments)],
        ["6", "Thương hiệu hỗ trợ khuyến mãi (100% tiền giảm giá)", "Trừ", money(invoice.get("brand_promotion_support"))],
        ["7", "Tiền dư chuyển từ kỳ trước", "Trừ", money(invoice.get("carried_credit"))],
    ]
    table: list[list[Any]] = [[Paragraph(f"<b>{h}</b>", s["cell"]) for h in ("STT", "Khoản mục", "Loại", "Số tiền (đ)")]]
    for no, label, kind, amount in rows:
        table.append([Paragraph(no, s["cell"]), Paragraph(label, s["cell"]), Paragraph(kind, s["cell"]),
                      Paragraph(amount, s["cell_right"])])
    for label, key, bold in (("Cộng tiền phí trước thuế", "taxable_amount", False),
                             (f"Thuế GTGT ({pct(invoice.get('vat_rate'))}%)", "vat_amount", False),
                             ("TỔNG CỘNG PHẢI THANH TOÁN", "invoice_total", True)):
        style = s["cell_right_bold"] if bold else s["cell_right"]
        table.append(["", Paragraph(f"<b>{label}</b>" if bold else label, s["cell"]), "",
                      Paragraph(money(invoice.get(key)), style)])
    fee_table = _grid(table, [12 * mm, 98 * mm, 24 * mm, 40 * mm])
    fee_table.setStyle(TableStyle([("SPAN", (1, len(table) - 1), (2, len(table) - 1)),
                                   ("BACKGROUND", (0, len(table) - 1), (-1, len(table) - 1), colors.HexColor("#FFF4D6"))]))

    payments = [p for p in invoice.get("payments") or [] if isinstance(p, dict)]
    payment_rows: list[list[Any]] = [[Paragraph(f"<b>{h}</b>", s["cell"]) for h in
                                      ("Mã thanh toán", "Ngày", "Hình thức", "Số tiền (đ)", "Trạng thái")]]
    for p in payments:
        payment_rows.append([
            Paragraph(str(p.get("payment_no")), s["cell"]), Paragraph(vn_date(p.get("payment_date")), s["cell"]),
            Paragraph(_METHODS.get(str(p.get("method")), str(p.get("method"))), s["cell"]),
            Paragraph(money(p.get("amount")), s["cell_right"]),
            Paragraph("Đã đảo" if p.get("status") == "REVERSED" else "Đã xác nhận", s["cell"]),
        ])

    status = str(invoice.get("status") or "")
    header = Table([[
        Paragraph(f"<b>{BRAND['name']}</b><br/>{BRAND['address']}<br/>ĐT: {BRAND['phone']} - {BRAND['email']}", s["small"]),
        Paragraph(f"Số: <b>{invoice.get('invoice_no') or '—'}</b><br/>Kỳ phí: <b>{period_text}</b><br/>"
                  f"Ngày phát hành: {vn_date(invoice.get('issued_at'))}<br/>Hạn thanh toán: <b>{vn_date(invoice.get('due_date'))}</b>",
                  s["right"]),
    ]], colWidths=[104 * mm, 70 * mm])
    header.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
    story: list[Any] = [
        header,
        Spacer(1, 3 * mm),
        Paragraph(f"THÔNG BÁO PHÍ NHƯỢNG QUYỀN THÁNG {period_text}", s["title"]),
        Paragraph(f"Trạng thái: {_INVOICE_STATUS.get(status, status)}", s["subtitle"]),
        Paragraph("Kính gửi bên nhận quyền", s["heading"]),
        _grid([
            [Paragraph("Chủ cửa hàng", s["cell"]), Paragraph(f"<b>{invoice.get('owner_name') or '—'}</b>", s["cell"])],
            [Paragraph("Cửa hàng", s["cell"]), Paragraph(f"{invoice.get('store_name') or '—'} (mã {invoice.get('store_code') or '—'})", s["cell"])],
            [Paragraph("Địa chỉ", s["cell"]), Paragraph(invoice.get("store_address") or "—", s["cell"])],
            [Paragraph("Hợp đồng", s["cell"]), Paragraph(invoice.get("contract_no") or "—", s["cell"])],
        ], [40 * mm, 134 * mm], header=False),
        Paragraph("Chi tiết phí", s["heading"]),
        fee_table,
        Spacer(1, 2 * mm),
        Paragraph(f"<b>Số tiền bằng chữ:</b> <i>{amount_in_words(invoice.get('invoice_total'))}.</i>", s["base"]),
        Spacer(1, 2 * mm),
        _grid([
            [Paragraph("Đã thanh toán", s["cell"]), Paragraph(f"{money(invoice.get('paid_amount'))} đ", s["cell_right"])],
            [Paragraph("<b>Còn phải thanh toán</b>", s["cell"]),
             Paragraph(f"<b>{money(invoice.get('outstanding_amount'))} đ</b>", s["cell_right"])],
        ], [134 * mm, 40 * mm], header=False),
    ]
    if len(payment_rows) > 1:
        story += [Paragraph("Lịch sử thanh toán", s["heading"]),
                  _grid(payment_rows, [52 * mm, 23 * mm, 28 * mm, 37 * mm, 34 * mm], zebra=True)]
    story += [
        Paragraph("Thông tin thanh toán", s["heading"]),
        Paragraph(f"Chuyển khoản tới: {BRAND['account_name']} - {BRAND['bank']}.<br/>"
                  f"Nội dung chuyển khoản: <b>{invoice.get('invoice_no') or ''} {invoice.get('store_code') or ''}</b>.", s["base"]),
        Spacer(1, 2 * mm),
        Paragraph("Ghi chú: Đây là thông báo phí nội bộ theo hợp đồng nhượng quyền, dùng để đối soát công nợ; "
                  "không thay thế hóa đơn điện tử giá trị gia tăng theo quy định về hóa đơn.", s["small"]),
        Spacer(1, 3 * mm),
        KeepTogether(_signatures("NGƯỜI LẬP", "Phòng Kế toán", "XÁC NHẬN CỦA BÊN NHẬN QUYỀN",
                                 invoice.get("owner_name") or "", s)),
    ]
    watermark = {"DRAFT": "BẢN NHÁP", "CANCELLED": "ĐÃ HỦY", "PAID": "ĐÃ THANH TOÁN"}.get(status)
    return _build(story, f"Thông báo phí {invoice.get('invoice_no') or ''}", watermark)


# --------------------------------------------------------------------------- spreadsheets
REPORT_COLUMNS = [
    ("store_code", "Mã cửa hàng"),
    ("store_name", "Tên cửa hàng"),
    ("gross_revenue", "Doanh thu gộp (đ)"),
    ("promotion_discount", "Giảm giá khuyến mãi (đ)"),
    ("net_revenue", "Doanh thu thuần (đ)"),
    ("royalty_fee", "Phí bản quyền (đ)"),
    ("brand_support", "Thương hiệu hỗ trợ KM (đ)"),
    ("invoice_total", "Tổng phí phải thu (đ)"),
    ("paid_amount", "Đã thu (đ)"),
    ("outstanding_amount", "Còn phải thu (đ)"),
]
_TEXT_COLUMNS = {"store_code", "store_name"}


def financial_report_rows(rows: list[dict[str, Any]]) -> tuple[list[str], list[list[Any]]]:
    """Vietnamese headers, report rows and a totals row for the financial summary."""
    headers = [label for _, label in REPORT_COLUMNS]
    body: list[list[Any]] = []
    totals = {key: Decimal(0) for key, _ in REPORT_COLUMNS if key not in _TEXT_COLUMNS}
    for row in rows:
        line: list[Any] = []
        for key, _ in REPORT_COLUMNS:
            if key in _TEXT_COLUMNS:
                line.append(row.get(key) or "")
            else:
                value = int(_num(row.get(key)))
                totals[key] += value
                line.append(value)
        body.append(line)
    body.append(["TỔNG CỘNG", f"{len(rows)} cửa hàng"] + [int(totals[key]) for key, _ in REPORT_COLUMNS[2:]])
    return headers, body


def to_csv(rows: list[dict[str, Any]], headers: list[str] | None = None,
           body: list[list[Any]] | None = None, title_lines: list[str] | None = None) -> bytes:
    """CSV in UTF-8 with BOM so Excel shows Vietnamese correctly.

    Called with dict rows (generic export) or with explicit headers and body.
    """
    output = StringIO()
    writer = csv.writer(output)
    for line in title_lines or []:
        writer.writerow([line])
    if title_lines:
        writer.writerow([])
    if headers is not None and body is not None:
        writer.writerow(headers)
        writer.writerows(body)
    elif rows:
        fieldnames = list(rows[0])
        dict_writer = csv.DictWriter(output, fieldnames=fieldnames)
        dict_writer.writeheader()
        dict_writer.writerows(rows)
    return output.getvalue().encode("utf-8-sig")


def to_xlsx(rows: list[dict[str, Any]], sheet_name: str = "Report",
            headers: list[str] | None = None, body: list[list[Any]] | None = None,
            title_lines: list[str] | None = None) -> bytes:
    workbook = Workbook()
    sheet = workbook.active
    assert sheet is not None
    sheet.title = sheet_name[:31]
    if headers is None or body is None:
        headers = list(rows[0]) if rows else []
        body = [[row.get(header) for header in headers] for row in rows]
    start = 1
    for title in title_lines or []:
        sheet.cell(row=start, column=1, value=title).font = Font(bold=start == 1, size=13 if start == 1 else 10)
        start += 1
    if title_lines:
        start += 1
    thin = Side(style="thin", color="9AA5B1")
    border = Border(left=thin, right=thin, top=thin, bottom=thin)
    for col, header in enumerate(headers, start=1):
        head_cell = sheet.cell(row=start, column=col, value=header)
        head_cell.font = Font(bold=True)
        head_cell.fill = PatternFill("solid", fgColor="DCE6F1")
        head_cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        head_cell.border = border
    for r, values in enumerate(body, start=start + 1):
        for c, value in enumerate(values, start=1):
            data_cell = sheet.cell(row=r, column=c, value=value)
            data_cell.border = border
            if isinstance(value, (int, float, Decimal)):
                data_cell.number_format = "#,##0"
    if body and title_lines:
        for total_cell in sheet[start + len(body)]:
            total_cell.font = Font(bold=True)
            total_cell.fill = PatternFill("solid", fgColor="FFF4D6")
    if headers:
        sheet.freeze_panes = f"A{start + 1}"
        sheet.auto_filter.ref = f"A{start}:{get_column_letter(len(headers))}{start + max(len(body), 1)}"
        for index, column in enumerate(sheet.iter_cols(min_row=start), start=1):
            width = min(max(len(str(cell.value or "")) for cell in column) + 3, 42)
            sheet.column_dimensions[get_column_letter(index)].width = max(width, 12)
    output = BytesIO()
    workbook.save(output)
    return output.getvalue()

