"use strict";

const state = {
  apiUrl: "http://localhost:8000",
  accessToken: sessionStorage.getItem("franchise.accessToken") || "",
  user: null,
  resource: "stores",
  items: [],
  page: 1,
  pageSize: 20,
  total: 0,
  references: { stores: new Map(), invoices: new Map() },
  dialogSubmit: null,
};

const resources = {
  applications: {
    title: "Hồ sơ đăng ký",
    eyebrow: "TIẾP NHẬN NHƯỢNG QUYỀN",
    path: "/api/v1/applications",
    statuses: ["PENDING", "UNDER_REVIEW", "APPROVED", "REJECTED", "WITHDRAWN"],
    columns: ["proposed_store_name", "applicant_name", "email", "proposed_address", "investment_budget", "status", "created_at"],
  },
  stores: {
    title: "Cửa hàng",
    eyebrow: "VẬN HÀNH CHUỖI",
    path: "/api/v1/stores",
    statuses: ["INACTIVE", "ACTIVE", "SUSPENDED", "CLOSED"],
    columns: ["code", "name", "address", "phone", "email", "status", "activated_at"],
  },
  contracts: {
    title: "Hợp đồng nhượng quyền",
    eyebrow: "HỢP ĐỒNG",
    path: "/api/v1/contracts",
    statuses: ["DRAFT", "ACTIVE", "EXPIRED", "TERMINATED"],
    columns: ["contract_no", "store_name", "effective_from", "effective_to", "royalty_rate", "initial_franchise_fee", "status"],
  },
  promotions: {
    title: "Khuyến mãi",
    eyebrow: "CHƯƠNG TRÌNH KHUYẾN MÃI",
    path: "/api/v1/promotions",
    statuses: ["DRAFT", "ACTIVE", "CANCELLED", "EXPIRED"],
    columns: ["name", "discount_type", "discount_value", "start_date", "end_date", "status"],
  },
  revenues: {
    title: "Doanh thu hằng ngày",
    eyebrow: "BÁO CÁO DOANH THU",
    path: "/api/v1/revenues",
    statuses: ["DRAFT", "SUBMITTED", "APPROVED", "REJECTED", "ADJUSTMENT_REQUESTED"],
    columns: ["business_date", "store_id", "gross_revenue", "promotion_discount", "net_revenue", "version", "status"],
  },
  invoices: {
    title: "Hóa đơn phí nhượng quyền",
    eyebrow: "HÓA ĐƠN VÀ CÔNG NỢ",
    path: "/api/v1/invoices",
    statuses: ["DRAFT", "ISSUED", "PARTIALLY_PAID", "PAID", "OVERDUE", "CANCELLED"],
    columns: ["invoice_no", "store_id", "period_month", "royalty_fee", "brand_promotion_support", "invoice_total", "paid_amount", "outstanding_amount", "due_date", "status"],
  },
  payments: {
    title: "Thanh toán",
    eyebrow: "ĐỐI SOÁT THANH TOÁN",
    path: "/api/v1/payments",
    statuses: ["CONFIRMED", "REVERSED"],
    columns: ["payment_no", "invoice_id", "amount", "payment_date", "method", "reference_no", "status"],
  },
  notifications: {
    title: "Thông báo",
    eyebrow: "TRUNG TÂM THÔNG BÁO",
    path: "/api/v1/notifications",
    statuses: [],
    columns: ["title", "message", "notification_type", "entity_type", "read_at", "created_at"],
  },
  audit_logs: {
    title: "Nhật ký hệ thống",
    eyebrow: "NHẬT KÝ THAO TÁC",
    path: "/api/v1/audit-logs",
    statuses: [],
    columns: ["action", "entity_type", "entity_id", "actor_id", "reason", "created_at"],
  },
};

const labels = {
  proposed_store_name: "Cửa hàng đề xuất",
  applicant_name: "Người đăng ký",
  proposed_address: "Địa chỉ đề xuất",
  investment_budget: "Ngân sách",
  created_at: "Ngày tạo",
  activated_at: "Ngày kích hoạt",
  contract_no: "Số hợp đồng",
  store_id: "Cửa hàng",
  effective_from: "Hiệu lực từ",
  effective_to: "Hiệu lực đến",
  royalty_rate: "Phí bản quyền (%)",
  initial_franchise_fee: "Phí ban đầu",
  discount_type: "Loại giảm",
  discount_value: "Mức giảm",
  start_date: "Bắt đầu",
  end_date: "Kết thúc",
  business_date: "Ngày kinh doanh",
  gross_revenue: "Doanh thu gộp",
  promotion_discount: "Giảm giá",
  net_revenue: "Doanh thu thuần",
  version: "Phiên bản",
  invoice_no: "Số hóa đơn",
  period_month: "Kỳ phí",
  royalty_fee: "Phí bản quyền",
  brand_promotion_support: "Thương hiệu hỗ trợ KM",
  invoice_total: "Tổng hóa đơn",
  paid_amount: "Đã thanh toán",
  outstanding_amount: "Còn phải trả",
  due_date: "Hạn thanh toán",
  payment_no: "Mã thanh toán",
  invoice_id: "Hóa đơn",
  payment_date: "Ngày thanh toán",
  method: "Phương thức",
  reference_no: "Mã tham chiếu",
  notification_type: "Loại thông báo",
  entity_type: "Đối tượng",
  read_at: "Đã đọc lúc",
  status: "Trạng thái",
  name: "Tên",
  code: "Mã",
  address: "Địa chỉ",
  phone: "Điện thoại",
  email: "Email",
  title: "Tiêu đề",
  message: "Nội dung",
  amount: "Số tiền",
  action: "Hành động",
  entity_id: "Mã đối tượng",
  actor_id: "Người thực hiện",
  reason: "Lý do",
  store_name: "Cửa hàng",
  store_code: "Mã cửa hàng",
  brand_support: "Thương hiệu hỗ trợ KM",
  converted_at: "Ngày mở cửa hàng",
};

const actionLabels = {
  REGISTER_USER: "Đăng ký tài khoản", LOGIN_SUCCESS: "Đăng nhập", PASSWORD_RESET: "Đặt lại mật khẩu",
  CHANGE_USER_STATUS: "Đổi trạng thái tài khoản", ASSIGN_ROLE: "Gán vai trò", REMOVE_ROLE: "Gỡ vai trò",
  SUBMIT_APPLICATION: "Nộp hồ sơ", WITHDRAW_APPLICATION: "Rút hồ sơ", START_APPLICATION_REVIEW: "Thẩm định hồ sơ",
  START_REVIEW: "Thẩm định hồ sơ", APPROVE_APPLICATION: "Duyệt hồ sơ", REJECT_APPLICATION: "Từ chối hồ sơ",
  CREATE_STORE: "Mở cửa hàng", CREATE_CONTRACT: "Lập hợp đồng", RECORD_CONTRACT_PAYMENT: "Ghi nhận phí hợp đồng",
  ACTIVATE_CONTRACT: "Kích hoạt hợp đồng", CREATE_PROMOTION: "Tạo khuyến mãi", ACTIVATE_PROMOTION: "Kích hoạt khuyến mãi",
  CANCEL_PROMOTION: "Hủy khuyến mãi", SOFT_DELETE_PROMOTION: "Xóa khuyến mãi", SAVE_REVENUE: "Lưu doanh thu",
  CREATE_REVENUE: "Lưu doanh thu", UPDATE_REVENUE: "Sửa doanh thu", SUBMIT_REVENUE: "Gửi duyệt doanh thu",
  APPROVE_REVENUE: "Duyệt doanh thu", REJECT_REVENUE: "Từ chối doanh thu", REQUEST_REVENUE_ADJUSTMENT: "Yêu cầu điều chỉnh doanh thu",
  REVENUE_VERSION: "Lưu phiên bản doanh thu", CREATE_BILLING_ADJUSTMENT: "Tạo điều chỉnh phí", GENERATE_INVOICE: "Lập hóa đơn",
  ISSUE_INVOICE: "Phát hành hóa đơn", CANCEL_INVOICE: "Hủy hóa đơn", RECORD_PAYMENT: "Ghi nhận thanh toán",
  REVERSE_PAYMENT: "Đảo thanh toán",
};

const entityLabels = {
  USER: "Tài khoản", APPLICATION: "Hồ sơ", STORE: "Cửa hàng", CONTRACT: "Hợp đồng", PROMOTION: "Khuyến mãi",
  REVENUE: "Doanh thu", INVOICE: "Hóa đơn", PAYMENT: "Thanh toán", BILLING_ADJUSTMENT: "Điều chỉnh phí",
};

const notificationLabels = {
  APPLICATION_APPROVED: "Hồ sơ được duyệt", APPLICATION_REJECTED: "Hồ sơ bị từ chối",
  PROMOTION_STARTED: "Khuyến mãi bắt đầu", REVENUE_SUBMITTED: "Doanh thu chờ duyệt",
  REVENUE_APPROVED: "Doanh thu đã duyệt", REVENUE_REJECTED: "Doanh thu bị từ chối",
  REVENUE_ADJUSTMENT_REQUESTED: "Yêu cầu điều chỉnh doanh thu", REVENUE_OVERDUE: "Chậm báo cáo doanh thu",
  INVOICE_ISSUED: "Hóa đơn đã phát hành", INVOICE_OVERDUE: "Hóa đơn quá hạn",
  PAYMENT_CONFIRMED: "Đã ghi nhận thanh toán", PAYMENT_REVERSED: "Thanh toán bị đảo",
};

const errorMessages = {
  ACTIVE_CONTRACT_ALREADY_EXISTS: "Cửa hàng đã có hợp đồng đang hiệu lực.",
  ACTIVE_CONTRACT_NOT_FOUND: "Cửa hàng chưa có hợp đồng hiệu lực trong kỳ này.",
  ACTIVE_PROMOTION_CANNOT_BE_DELETED: "Không thể xóa khuyến mãi đang hoạt động, hãy hủy trước.",
  ADJUSTMENT_REASON_REQUIRED: "Cần nhập lý do điều chỉnh.",
  APPLICATION_ALREADY_CONVERTED_TO_STORE: "Hồ sơ này đã được mở cửa hàng.",
  APPLICATION_CANNOT_BE_WITHDRAWN_FROM_STATUS: "Không thể rút hồ sơ ở trạng thái hiện tại.",
  APPLICATION_MUST_BE_APPROVED: "Hồ sơ phải được duyệt trước.",
  APPLICATION_MUST_BE_PENDING: "Chỉ thẩm định được hồ sơ đang chờ xử lý.",
  APPLICATION_MUST_BE_UNDER_REVIEW: "Hồ sơ phải đang được thẩm định.",
  APPLICATION_NOT_FOUND: "Không tìm thấy hồ sơ.",
  APPLICATION_OWNERSHIP_REQUIRED: "Bạn chỉ thao tác được trên hồ sơ của mình.",
  BILLING_ADJUSTMENT_INVALID: "Khoản điều chỉnh không hợp lệ.",
  CANCEL_REASON_REQUIRED: "Cần nhập lý do hủy.",
  CONTRACT_ALREADY_EXISTS_FOR_APPLICATION: "Hồ sơ này đã có hợp đồng.",
  CONTRACT_FINANCIAL_TRANSACTION_INVALID: "Khoản thu hợp đồng không hợp lệ.",
  CONTRACT_MUST_BE_DRAFT: "Chỉ thao tác được trên hợp đồng nháp.",
  CONTRACT_NOT_FOUND: "Không tìm thấy hợp đồng.",
  CONTRACT_SIGNED_DATE_REQUIRED: "Hợp đồng cần có ngày ký trước khi kích hoạt.",
  DELETE_REASON_REQUIRED: "Cần nhập lý do xóa.",
  EMAIL_ALREADY_EXISTS: "Email này đã được đăng ký.",
  INITIAL_FEE_20_PERCENT_REQUIRED: "Cần thu tối thiểu 20% phí nhượng quyền ban đầu trước khi kích hoạt (tối thiểu {0} ₫).",
  INVOICE_ALREADY_EXISTS_FOR_PERIOD: "Cửa hàng đã có hóa đơn cho kỳ này.",
  INVOICE_CANNOT_BE_CANCELLED: "Không thể hủy hóa đơn đã có thanh toán.",
  INVOICE_MUST_BE_DRAFT: "Chỉ phát hành được hóa đơn nháp.",
  INVOICE_NOT_FOUND: "Không tìm thấy hóa đơn.",
  INVOICE_NOT_PAYABLE: "Hóa đơn chưa ở trạng thái nhận thanh toán.",
  LAST_ACTIVE_ADMIN_REQUIRED: "Hệ thống cần ít nhất một quản trị viên đang hoạt động.",
  NOTIFICATION_NOT_FOUND: "Không tìm thấy thông báo.",
  OPEN_APPLICATION_ALREADY_EXISTS: "Bạn đã có một hồ sơ đang được xử lý.",
  PASSWORD_RESET_TOKEN_INVALID: "Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.",
  PAYMENT_ALREADY_REVERSED: "Thanh toán này đã được đảo.",
  PAYMENT_AMOUNT_INVALID_OR_EXCEEDS_OUTSTANDING: "Số tiền thanh toán không hợp lệ hoặc vượt công nợ.",
  PAYMENT_NOT_FOUND: "Không tìm thấy thanh toán.",
  PROMOTION_CANNOT_BE_CANCELLED: "Không thể hủy khuyến mãi ở trạng thái hiện tại.",
  PROMOTION_DISCOUNT_EXCEEDS_GROSS: "Tiền giảm giá không được vượt doanh thu gộp.",
  PROMOTION_DISCOUNT_INVALID: "Tiền giảm giá không hợp lệ.",
  PROMOTION_MUST_BE_DRAFT: "Chỉ kích hoạt được khuyến mãi nháp.",
  PROMOTION_NAME_REQUIRED: "Cần nhập tên chương trình.",
  PROMOTION_NOT_APPLICABLE: "Khuyến mãi không áp dụng cho cửa hàng hoặc ngày này.",
  PROMOTION_NOT_FOUND: "Không tìm thấy khuyến mãi.",
  PROMOTION_STORES_REQUIRED: "Cần chọn cửa hàng áp dụng.",
  REJECTION_REASON_REQUIRED: "Cần nhập lý do từ chối.",
  REVENUE_ALREADY_EXISTS_FOR_DATE: "Cửa hàng đã báo doanh thu cho ngày này.",
  REVENUE_AMOUNT_INVALID: "Số tiền doanh thu không hợp lệ.",
  REVENUE_BUSINESS_DATE_INVALID: "Ngày kinh doanh không hợp lệ: không được trước ngày mở cửa hàng hoặc sau hôm nay.",
  REVENUE_CANNOT_BE_EDITED: "Không thể sửa doanh thu ở trạng thái hiện tại.",
  REVENUE_CANNOT_BE_SUBMITTED: "Không thể gửi duyệt doanh thu ở trạng thái hiện tại.",
  REVENUE_DECISION_INVALID: "Quyết định duyệt không hợp lệ.",
  REVENUE_MUST_BE_APPROVED: "Doanh thu phải được duyệt trước.",
  REVENUE_MUST_BE_SUBMITTED: "Doanh thu phải đang chờ duyệt.",
  REVENUE_NOT_FOUND: "Không tìm thấy doanh thu.",
  REVENUE_SELF_APPROVAL_FORBIDDEN: "Người báo doanh thu không được tự duyệt.",
  REVERSAL_REASON_REQUIRED: "Cần nhập lý do đảo thanh toán.",
  ROLE_ALREADY_ASSIGNED: "Người dùng đã có vai trò này.",
  ROLE_NOT_ASSIGNED: "Người dùng chưa có vai trò này.",
  ROLE_NOT_FOUND: "Vai trò không hợp lệ.",
  ROLE_REQUIRED: "Bạn không có quyền thực hiện thao tác này.",
  STATUS_CHANGE_REASON_REQUIRED: "Cần nhập lý do đổi trạng thái.",
  STORE_CODE_ALREADY_EXISTS: "Mã cửa hàng đã tồn tại.",
  STORE_INFORMATION_REQUIRED: "Cần nhập mã, tên và địa chỉ cửa hàng.",
  STORE_NOT_ACTIVE: "Cửa hàng chưa hoạt động.",
  STORE_NOT_FOUND: "Không tìm thấy cửa hàng.",
  STORE_OWNERSHIP_REQUIRED: "Bạn chỉ thao tác được trên cửa hàng của mình.",
  USER_NOT_ACTIVE: "Tài khoản không hoạt động.",
  USER_NOT_FOUND: "Không tìm thấy tài khoản.",
  USER_STATUS_INVALID: "Trạng thái tài khoản không hợp lệ.",
  VAT_RATE_INVALID: "Thuế VAT phải từ 0 đến 100%.",
  "Email or password is incorrect": "Email hoặc mật khẩu không đúng.",
  "Bearer token is required": "Phiên đăng nhập đã hết, vui lòng đăng nhập lại.",
  "Invalid or expired token": "Phiên đăng nhập đã hết, vui lòng đăng nhập lại.",
  "User is not active": "Tài khoản không hoạt động.",
  "Insufficient permission": "Bạn không có quyền thực hiện thao tác này.",
  "Store access denied": "Bạn không có quyền xem cửa hàng này.",
  "Contract not found": "Không tìm thấy hợp đồng.",
  "File is too large": "Tệp quá lớn (tối đa 10 MB).",
  "Maximum 5000 rows": "Tệp có tối đa 5.000 dòng.",
  "Format must be csv or xlsx": "Chỉ hỗ trợ tệp CSV hoặc Excel.",
  "Only CSV and XLSX files are supported": "Chỉ hỗ trợ tệp CSV hoặc Excel.",
  "Rate limit exceeded": "Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút.",
  "Invalid email address": "Email không hợp lệ.",
  "Full name is required": "Cần nhập họ và tên.",
  "Password must contain at least 8 characters": "Mật khẩu cần tối thiểu 8 ký tự.",
  "Password must not exceed 128 characters": "Mật khẩu tối đa 128 ký tự.",
  "Contract number is required": "Cần nhập số hợp đồng.",
  "Contract end date cannot precede start date": "Ngày kết thúc hợp đồng không được trước ngày bắt đầu.",
  "Royalty rate must be between 0 and 100": "Phí bản quyền phải từ 0 đến 100%.",
  "Contract amounts cannot be negative": "Các khoản phí hợp đồng không được âm.",
  "Proposed area must be greater than zero": "Diện tích phải lớn hơn 0.",
  "Investment budget cannot be negative": "Ngân sách đầu tư không được âm.",
  "Rejection reason is required": "Cần nhập lý do từ chối.",
  "Adjustment reason is required": "Cần nhập lý do điều chỉnh.",
  "Invalid report period": "Khoảng thời gian báo cáo không hợp lệ.",
};

function translateError(detail) {
  const text = String(detail || "").trim();
  if (errorMessages[text]) return errorMessages[text];
  const [code, ...rest] = text.split(":");
  if (errorMessages[code]) {
    const extra = rest.join(":").trim();
    const amount = Number(extra);
    const value = extra && !Number.isNaN(amount) ? new Intl.NumberFormat("vi-VN").format(amount) : extra;
    return errorMessages[code].replace("{0}", value);
  }
  if (text.startsWith("Required fields are empty") || text.startsWith("Store information is required")) return "Cần nhập đủ các thông tin bắt buộc.";
  if (/^[A-Z][A-Z0-9_]+$/.test(code)) return `Thao tác không thành công (mã lỗi ${code}).`;
  return text;
}

const moneyFields = new Set([
  "investment_budget", "initial_franchise_fee", "discount_value", "gross_revenue",
  "promotion_discount", "net_revenue", "invoice_total", "paid_amount",
  "outstanding_amount", "amount", "royalty_fee", "brand_promotion_support", "brand_support",
]);

const element = (id) => document.getElementById(id);
const today = () => new Date().toISOString().slice(0, 10);
const monthStart = () => `${today().slice(0, 7)}-01`;
const hasRole = (role) => Boolean(state.user?.roles?.includes(role));

function showToast(message, error = false) {
  const toast = element("toast");
  toast.textContent = message;
  toast.classList.toggle("toast-error", error);
  toast.classList.remove("hidden");
  window.clearTimeout(showToast.timeout);
  showToast.timeout = window.setTimeout(() => toast.classList.add("hidden"), 3500);
}

function setSession(accessToken) {
  state.accessToken = accessToken || "";
  sessionStorage.removeItem("franchise.refreshToken");
  if (state.accessToken) sessionStorage.setItem("franchise.accessToken", state.accessToken);
  else sessionStorage.removeItem("franchise.accessToken");
}

async function apiRequest(path, options = {}) {
  const headers = new Headers(options.headers || {});
  if (state.accessToken) headers.set("Authorization", `Bearer ${state.accessToken}`);
  if (options.body && !(options.body instanceof FormData) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  let response;
  try {
    response = await fetch(`${state.apiUrl}${path}`, { ...options, headers });
  } catch (error) {
    throw new Error("Không kết nối được máy chủ. Hãy kiểm tra Docker Desktop.", { cause: error });
  }
  if (response.status === 401 && state.accessToken && !path.includes("/auth/login")) {
    setSession("");
    showLogin();
  }
  const contentType = response.headers.get("content-type") || "";
  let data = null;
  if (response.status !== 204) {
    data = contentType.includes("application/json") ? await response.json() : await response.blob();
  }
  return { ok: response.ok, status: response.status, data, headers: response.headers };
}

function resultMessage(result) {
  if (result?.data && !(result.data instanceof Blob)) {
    if (typeof result.data.detail === "string") return translateError(result.data.detail);
    if (Array.isArray(result.data.detail)) {
      const fieldsInvalid = result.data.detail.map((item) => {
        const key = Array.isArray(item.loc) ? item.loc[item.loc.length - 1] : "";
        return labels[key] || key;
      }).filter(Boolean);
      return `Dữ liệu chưa hợp lệ${fieldsInvalid.length ? `: ${[...new Set(fieldsInvalid)].join(", ")}` : "."}`;
    }
  }
  return `Thao tác không thành công (mã HTTP ${result?.status || "?"}).`;
}

async function checkHealth() {
  const badge = element("api-status");
  try {
    const response = await fetch(`${state.apiUrl}/health`);
    if (!response.ok) throw new Error();
    badge.textContent = "Hệ thống sẵn sàng";
    badge.className = "status status-online";
  } catch {
    badge.textContent = "Mất kết nối";
    badge.className = "status status-offline";
  }
}

function showLogin() {
  state.user = null;
  element("login-view").classList.remove("hidden");
  element("app-view").classList.add("hidden");
  element("logout-button").classList.add("hidden");
}

function showApplication() {
  element("login-view").classList.add("hidden");
  element("app-view").classList.remove("hidden");
  element("logout-button").classList.remove("hidden");
  const roleNames = { ADMIN: "Quản trị viên", STORE_OWNER: "Chủ cửa hàng", ACCOUNTANT: "Kế toán" };
  const roleText = (state.user.roles || []).map((role) => roleNames[role] || role).join(" · ") || "Người dùng";
  const box = element("current-user");
  box.replaceChildren();
  const name = document.createElement("strong");
  name.textContent = state.user.full_name;
  const email = document.createElement("span");
  email.textContent = state.user.email;
  const roles = document.createElement("span");
  roles.textContent = roleText;
  box.append(name, email, roles);
  document.querySelectorAll(".role-admin").forEach((item) => item.classList.toggle("hidden", !hasRole("ADMIN")));
}

async function loadCurrentUser() {
  const result = await apiRequest("/api/v1/auth/me");
  if (!result.ok) throw new Error(resultMessage(result));
  state.user = result.data;
  showApplication();
}

async function handleLogin(event) {
  event.preventDefault();
  const submit = event.submitter || event.currentTarget.querySelector("button[type='submit']");
  const message = element("login-message");
  submit.disabled = true;
  message.textContent = "Đang đăng nhập...";
  try {
    const result = await apiRequest("/api/v1/auth/login", {
      method: "POST",
      body: JSON.stringify({ email: element("email").value.trim(), password: element("password").value }),
    });
    if (!result.ok) throw new Error(resultMessage(result));
    setSession(result.data.access_token);
    await loadCurrentUser();
    message.textContent = "";
    await openView("dashboard");
  } catch (error) {
    message.textContent = error.message;
  } finally {
    submit.disabled = false;
    checkHealth();
  }
}

async function handleLogout() {
  setSession("");
  showLogin();
}

function setActiveSection(id) {
  document.querySelectorAll(".view-section").forEach((section) => section.classList.add("hidden"));
  element(id).classList.remove("hidden");
}

async function openView(view) {
  document.querySelectorAll(".nav-item").forEach((button) => button.classList.toggle("active", button.dataset.view === view));
  if (resources[view]) {
    state.resource = view;
    state.page = 1;
    element("search-filter").value = "";
    configureResourceHeader();
    setActiveSection("resource-section");
    await loadResource();
    return;
  }
  if (view === "dashboard") {
    setActiveSection("dashboard-section");
    await loadDashboard();
    return;
  }
  setActiveSection("report-section");
}

function primaryActionFor(resource) {
  if (resource === "applications" && !hasRole("ADMIN") && !hasRole("ACCOUNTANT")) return { label: "Nộp hồ sơ", action: openCreateApplication };
  if (resource === "applications" && hasRole("STORE_OWNER")) return { label: "Nộp hồ sơ", action: openCreateApplication };
  if (resource === "contracts" && hasRole("ADMIN")) return { label: "Lập hợp đồng", action: openCreateContract };
  if (resource === "promotions" && hasRole("ADMIN")) return { label: "Tạo khuyến mãi", action: openCreatePromotion };
  if (resource === "revenues" && hasRole("STORE_OWNER")) return { label: "Ghi nhận doanh thu", action: openCreateRevenue };
  if (resource === "invoices" && hasRole("ACCOUNTANT")) return { label: "Lập hóa đơn", action: openGenerateInvoice };
  return null;
}

function configureResourceHeader() {
  const config = resources[state.resource];
  element("resource-title").textContent = config.title;
  element("resource-eyebrow").textContent = config.eyebrow;
  const status = element("status-filter");
  status.replaceChildren(new Option("Tất cả trạng thái", ""));
  config.statuses.forEach((value) => status.append(new Option(statusLabel(value), value)));
  const action = primaryActionFor(state.resource);
  const button = element("primary-action");
  button.classList.toggle("hidden", !action);
  if (action) {
    button.textContent = action.label;
    button.onclick = action.action;
  }
  const canImport = state.resource === "revenues" && hasRole("STORE_OWNER");
  element("import-revenue").classList.toggle("hidden", !canImport);
  element("revenue-template").classList.toggle("hidden", !canImport);
}

async function fetchPage(resource, params = {}) {
  const query = new URLSearchParams({ page: "1", page_size: "200", ...params });
  return apiRequest(`${resources[resource].path}?${query}`);
}

async function loadReferenceMaps() {
  const [stores, invoices] = await Promise.all([fetchPage("stores"), fetchPage("invoices")]);
  state.references.stores = new Map((stores.ok ? stores.data.items : []).map((row) => [row.id, `${row.code} — ${row.name}`]));
  state.references.invoices = new Map((invoices.ok ? invoices.data.items : []).map((row) => [row.id, row.invoice_no]));
}

async function loadResource() {
  const config = resources[state.resource];
  const query = new URLSearchParams({ page: String(state.page), page_size: String(state.pageSize) });
  const search = element("search-filter").value.trim();
  const status = element("status-filter").value;
  if (search) query.set("search", search);
  if (status) query.set("status", status);
  if (["contracts", "revenues", "invoices", "payments"].includes(state.resource)) await loadReferenceMaps();
  try {
    const result = await apiRequest(`${config.path}?${query}`);
    if (!result.ok) throw new Error(resultMessage(result));
    state.items = result.data.items;
    state.total = result.data.total;
    renderResourceRows();
  } catch (error) {
    state.items = [];
    renderResourceRows();
    showToast(error.message, true);
  }
  element("page-info").textContent = `Trang ${state.page} · ${state.total} bản ghi`;
  element("previous-page").disabled = state.page <= 1;
  element("next-page").disabled = state.page * state.pageSize >= state.total;
}

function statusLabel(value) {
  const values = {
    PENDING: "Chờ xử lý", UNDER_REVIEW: "Đang thẩm định", APPROVED: "Đã duyệt",
    REJECTED: "Từ chối", WITHDRAWN: "Đã rút", INACTIVE: "Chưa hoạt động",
    ACTIVE: "Đang hoạt động", SUSPENDED: "Tạm ngưng", CLOSED: "Đã đóng",
    DRAFT: "Bản nháp", EXPIRED: "Hết hạn", TERMINATED: "Đã chấm dứt",
    CANCELLED: "Đã hủy", SUBMITTED: "Chờ duyệt", ADJUSTMENT_REQUESTED: "Yêu cầu điều chỉnh",
    ISSUED: "Đã phát hành", PARTIALLY_PAID: "Thanh toán một phần", PAID: "Đã thanh toán",
    OVERDUE: "Quá hạn", CONFIRMED: "Đã xác nhận", REVERSED: "Đã đảo",
  };
  return values[value] || value || "—";
}

function formatDate(value) {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat("vi-VN").format(date);
}

function displayValue(key, value, row = {}) {
  if (value === null || value === undefined || value === "") {
    if (key === "store_name" && row.store_code) return row.store_code;
    return "—";
  }
  if (key === "store_name" && row.store_code) return `${row.store_code} — ${value}${row.status === "DRAFT" ? " (chưa hoạt động)" : ""}`;
  if (key === "store_id") return state.references.stores.get(value) || value.slice(0, 8);
  if (key === "discount_value" && row.discount_type === "PERCENTAGE") return `${value}%`;
  if (key === "action") return actionLabels[value] || value;
  if (key === "entity_type") return entityLabels[value] || value;
  if (key === "notification_type") return notificationLabels[value] || value;
  if (key === "title" && row.notification_type && notificationLabels[row.notification_type]) return notificationLabels[row.notification_type];
  if (["entity_id", "actor_id"].includes(key)) return String(value).slice(0, 8);
  if (key === "invoice_id") return state.references.invoices.get(value) || value.slice(0, 8);
  if (key === "status") return statusLabel(value);
  if (moneyFields.has(key) && !Number.isNaN(Number(value))) return `${new Intl.NumberFormat("vi-VN").format(Number(value))} ₫`;
  if (key === "royalty_rate") return `${value}%`;
  if (key.endsWith("_at") || key.endsWith("_date") || ["effective_from", "effective_to", "period_month", "start_date", "end_date", "due_date"].includes(key)) return formatDate(value);
  if (key === "discount_type") return value === "PERCENTAGE" ? "Phần trăm" : "Số tiền cố định";
  if (key === "method") return { BANK_TRANSFER: "Chuyển khoản", CASH: "Tiền mặt", OTHER: "Khác" }[value] || value;
  return typeof value === "object" ? JSON.stringify(value) : String(value);
}

function renderResourceRows() {
  const config = resources[state.resource];
  const head = element("resource-head");
  const body = element("resource-body");
  head.replaceChildren();
  body.replaceChildren();
  element("resource-empty").classList.toggle("hidden", state.items.length > 0);
  if (!state.items.length) return;
  const header = document.createElement("tr");
  config.columns.forEach((key) => {
    const th = document.createElement("th");
    th.textContent = labels[key] || key;
    header.append(th);
  });
  const actionHead = document.createElement("th");
  actionHead.textContent = "Thao tác";
  header.append(actionHead);
  head.append(header);

  state.items.forEach((row) => {
    const tr = document.createElement("tr");
    config.columns.forEach((key) => {
      const td = document.createElement("td");
      if (key === "status") {
        const badge = document.createElement("span");
        badge.className = `status-pill status-${String(row[key] || "").toLowerCase()}`;
        badge.textContent = displayValue(key, row[key], row);
        td.append(badge);
      } else {
        td.textContent = displayValue(key, row[key], row);
        td.title = td.textContent;
      }
      tr.append(td);
    });
    const actions = document.createElement("td");
    actions.className = "row-actions";
    actionDescriptors(row).forEach(({ label, kind, handler }) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `table-action ${kind || ""}`;
      button.textContent = label;
      button.addEventListener("click", handler);
      actions.append(button);
    });
    if (!actions.childElementCount) actions.textContent = "—";
    tr.append(actions);
    body.append(tr);
  });
}

function actionDescriptors(row) {
  const actions = [];
  if (state.resource === "applications") {
    if (hasRole("ADMIN") && row.status === "PENDING") actions.push({ label: "Thẩm định", handler: () => directAction(`/api/v1/applications/${row.id}/start-review`, "POST", null, "Đã chuyển hồ sơ sang thẩm định.") });
    if (hasRole("ADMIN") && row.status === "UNDER_REVIEW") {
      actions.push({ label: "Duyệt", handler: () => openReasonAction("Duyệt hồ sơ", "Ghi chú duyệt", false, (note) => dialogAction(`/api/v1/applications/${row.id}/approve`, "POST", { note }, "Hồ sơ đã được duyệt.")) });
      actions.push({ label: "Từ chối", kind: "danger", handler: () => openReasonAction("Từ chối hồ sơ", "Lý do từ chối", true, (reason) => dialogAction(`/api/v1/applications/${row.id}/reject`, "POST", { reason }, "Hồ sơ đã bị từ chối.")) });
    }
    if (!hasRole("ADMIN") && ["PENDING", "UNDER_REVIEW"].includes(row.status)) actions.push({ label: "Rút hồ sơ", kind: "danger", handler: () => openReasonAction("Rút hồ sơ", "Lý do rút hồ sơ", true, (reason) => dialogAction(`/api/v1/applications/${row.id}/withdraw`, "POST", { reason }, "Đã rút hồ sơ.")) });
  }
  if (state.resource === "contracts") {
    actions.push({ label: "Tải PDF", handler: () => downloadProtected(`/api/v1/contracts/${row.id}/pdf`, `${row.contract_no}.pdf`) });
    if (hasRole("ADMIN") && row.status === "DRAFT") {
      actions.push({ label: "Ghi nhận phí", handler: () => openContractTransaction(row) });
      actions.push({ label: "Kích hoạt", handler: () => directAction(`/api/v1/contracts/${row.id}/activate`, "POST", null, "Hợp đồng đã kích hoạt, cửa hàng bắt đầu hoạt động.") });
    }
  }
  if (state.resource === "promotions" && hasRole("ADMIN")) {
    if (row.status === "DRAFT") actions.push({ label: "Kích hoạt", handler: () => directAction(`/api/v1/promotions/${row.id}/activate`, "POST", null, "Khuyến mãi đã được kích hoạt.") });
    if (["DRAFT", "ACTIVE"].includes(row.status)) actions.push({ label: "Hủy", kind: "danger", handler: () => openReasonAction("Hủy khuyến mãi", "Lý do hủy", true, (reason) => dialogAction(`/api/v1/promotions/${row.id}/cancel`, "POST", { reason }, "Khuyến mãi đã được hủy.")) });
    if (["DRAFT", "CANCELLED"].includes(row.status)) actions.push({ label: "Xóa", kind: "danger", handler: () => openReasonAction("Xóa khuyến mãi", "Lý do xóa", true, (reason) => dialogAction(`/api/v1/promotions/${row.id}`, "DELETE", { reason }, "Khuyến mãi đã được xóa mềm.")) });
  }
  if (state.resource === "revenues") {
    if (hasRole("STORE_OWNER") && ["DRAFT", "REJECTED"].includes(row.status)) actions.push({ label: "Gửi duyệt", handler: () => directAction(`/api/v1/revenues/${row.id}/submit`, "POST", null, "Doanh thu đã được gửi duyệt.") });
    if (hasRole("ACCOUNTANT") && row.status === "SUBMITTED") {
      actions.push({ label: "Duyệt", handler: () => openReasonAction("Duyệt doanh thu", "Ghi chú", false, (note) => dialogAction(`/api/v1/revenues/${row.id}/approve`, "POST", { note }, "Doanh thu đã được duyệt.")) });
      actions.push({ label: "Từ chối", kind: "danger", handler: () => openReasonAction("Từ chối doanh thu", "Lý do từ chối", true, (reason) => dialogAction(`/api/v1/revenues/${row.id}/reject`, "POST", { reason }, "Doanh thu đã bị từ chối.")) });
    }
    if (hasRole("ACCOUNTANT") && row.status === "APPROVED") actions.push({ label: "Yêu cầu điều chỉnh", handler: () => openReasonAction("Yêu cầu điều chỉnh", "Lý do điều chỉnh", true, (reason) => dialogAction(`/api/v1/revenues/${row.id}/request-adjustment`, "POST", { reason }, "Đã gửi yêu cầu điều chỉnh.")) });
  }
  if (state.resource === "invoices") {
    actions.push({ label: "Tải PDF", handler: () => downloadProtected(`/api/v1/invoices/${row.id}/pdf`, `${row.invoice_no}.pdf`) });
    if (hasRole("ACCOUNTANT") && row.status === "DRAFT") actions.push({ label: "Phát hành", handler: () => directAction(`/api/v1/invoices/${row.id}/issue`, "POST", null, "Hóa đơn đã được phát hành.") });
    if (hasRole("ACCOUNTANT") && ["ISSUED", "PARTIALLY_PAID", "OVERDUE"].includes(row.status)) actions.push({ label: "Thanh toán", handler: () => openPayment(row) });
    if (hasRole("ACCOUNTANT") && ["DRAFT", "ISSUED"].includes(row.status)) actions.push({ label: "Hủy", kind: "danger", handler: () => openReasonAction("Hủy hóa đơn", "Lý do hủy", true, (reason) => dialogAction(`/api/v1/invoices/${row.id}/cancel`, "POST", { reason }, "Hóa đơn đã được hủy.")) });
  }
  if (state.resource === "payments" && hasRole("ACCOUNTANT") && row.status === "CONFIRMED") actions.push({ label: "Đảo thanh toán", kind: "danger", handler: () => openReasonAction("Đảo thanh toán", "Lý do đảo", true, (reason) => dialogAction(`/api/v1/payments/${row.id}/reverse`, "POST", { reason }, "Thanh toán đã được đảo.")) });
  if (state.resource === "notifications" && !row.read_at) actions.push({ label: "Đánh dấu đã đọc", handler: () => directAction(`/api/v1/notifications/${row.id}/read`, "PATCH", null, "Đã đánh dấu thông báo.") });
  return actions;
}

async function directAction(path, method, body, successMessage) {
  try {
    const result = await apiRequest(path, { method, body: body ? JSON.stringify(body) : undefined });
    if (!result.ok) throw new Error(resultMessage(result));
    showToast(successMessage);
    await loadResource();
  } catch (error) {
    showToast(error.message, true);
  }
}

async function dialogAction(path, method, body, successMessage) {
  const result = await apiRequest(path, { method, body: body ? JSON.stringify(body) : undefined });
  if (!result.ok) throw new Error(resultMessage(result));
  showToast(successMessage);
}

function fieldControl(field) {
  const wrapper = document.createElement("label");
  wrapper.textContent = field.label;
  let control;
  if (field.type === "textarea") {
    control = document.createElement("textarea");
    control.rows = field.rows || 3;
  } else if (field.type === "select") {
    control = document.createElement("select");
    if (!field.required) control.append(new Option("— Không chọn —", ""));
    (field.options || []).forEach((option) => control.append(new Option(option.label, option.value)));
  } else {
    control = document.createElement("input");
    control.type = field.type || "text";
  }
  control.name = field.name;
  control.required = Boolean(field.required);
  if (field.value !== undefined) control.value = field.value;
  if (field.min !== undefined) control.min = field.min;
  if (field.max !== undefined) control.max = field.max;
  if (field.step !== undefined) control.step = field.step;
  if (field.placeholder) control.placeholder = field.placeholder;
  if (field.readOnly) control.readOnly = true;
  if (field.dataType) control.dataset.type = field.dataType;
  wrapper.append(control);
  return wrapper;
}

function openDialog({ title, description = "", fields, submitText = "Xác nhận", onSubmit }) {
  element("dialog-title").textContent = title;
  element("dialog-description").textContent = description;
  element("dialog-message").textContent = "";
  element("submit-operation").textContent = submitText;
  const container = element("dialog-fields");
  container.replaceChildren(...fields.map(fieldControl));
  state.dialogSubmit = onSubmit;
  element("operation-dialog").showModal();
}

function closeDialog() {
  element("operation-dialog").close();
  state.dialogSubmit = null;
}

function collectDialogValues() {
  const values = {};
  new FormData(element("operation-form")).forEach((value, key) => {
    const control = element("operation-form").elements.namedItem(key);
    if (control?.dataset?.type === "number") values[key] = value === "" ? null : Number(value);
    else values[key] = value === "" ? null : value;
  });
  return values;
}

async function submitDialog(event) {
  event.preventDefault();
  if (!state.dialogSubmit) return;
  const button = element("submit-operation");
  button.disabled = true;
  element("dialog-message").textContent = "Đang xử lý...";
  try {
    await state.dialogSubmit(collectDialogValues());
    closeDialog();
    if (state.user && !element("app-view").classList.contains("hidden")) await loadResource();
  } catch (error) {
    element("dialog-message").textContent = error.message;
  } finally {
    button.disabled = false;
  }
}

function openRegister() {
  openDialog({
    title: "Đăng ký tài khoản",
    description: "Sau khi đăng ký, bạn có thể đăng nhập và nộp hồ sơ nhượng quyền.",
    submitText: "Đăng ký",
    fields: [
      { name: "full_name", label: "Họ và tên", required: true },
      { name: "email", label: "Email", type: "email", required: true },
      { name: "phone", label: "Điện thoại", type: "tel" },
      { name: "password", label: "Mật khẩu", type: "password", required: true, placeholder: "Tối thiểu 8 ký tự" },
    ],
    onSubmit: async (values) => {
      const result = await apiRequest("/api/v1/auth/register", { method: "POST", body: JSON.stringify(values) });
      if (!result.ok) throw new Error(resultMessage(result));
      element("email").value = values.email;
      element("password").value = values.password;
      showToast("Đăng ký thành công. Hãy đăng nhập để nộp hồ sơ.");
    },
  });
}

async function submitCreation(path, values, successMessage) {
  const result = await apiRequest(path, { method: "POST", body: JSON.stringify(values) });
  if (!result.ok) throw new Error(resultMessage(result));
  showToast(successMessage);
  return result.data;
}

function openCreateApplication() {
  openDialog({
    title: "Nộp hồ sơ nhượng quyền",
    description: "Cung cấp thông tin người đăng ký và địa điểm dự kiến.",
    submitText: "Nộp hồ sơ",
    fields: [
      { name: "applicant_name", label: "Họ và tên", required: true, value: state.user.full_name },
      { name: "email", label: "Email", type: "email", required: true, value: state.user.email },
      { name: "phone", label: "Điện thoại", type: "tel", required: true, value: state.user.phone || "" },
      { name: "proposed_store_name", label: "Tên cửa hàng đề xuất", required: true },
      { name: "proposed_address", label: "Địa chỉ đề xuất", required: true },
      { name: "proposed_area", label: "Diện tích (m²)", type: "number", dataType: "number", min: 1, step: 0.1 },
      { name: "investment_budget", label: "Ngân sách đầu tư (VND)", type: "number", dataType: "number", min: 0, step: 1000 },
      { name: "note", label: "Ghi chú", type: "textarea" },
    ],
    onSubmit: (values) => submitCreation("/api/v1/applications", values, "Hồ sơ đã được nộp."),
  });
}

async function openCreateContract() {
  const [applications, contracts] = await Promise.all([
    fetchPage("applications", { status: "APPROVED" }),
    fetchPage("contracts"),
  ]);
  if (!applications.ok) return showToast(resultMessage(applications), true);
  const taken = new Set((contracts.ok ? contracts.data.items : [])
    .filter((item) => ["DRAFT", "ACTIVE"].includes(item.status))
    .map((item) => item.application_id));
  const available = applications.data.items.filter((item) => !item.converted_at && !taken.has(item.id));
  if (!available.length) return showToast("Không có hồ sơ đã duyệt đang chờ lập hợp đồng.", true);
  const nextYear = new Date();
  nextYear.setFullYear(nextYear.getFullYear() + 1);
  openDialog({
    title: "Lập hợp đồng nhượng quyền",
    description: "Lập hợp đồng sẽ tự tạo cửa hàng (mã tự sinh, tên và địa chỉ lấy từ hồ sơ) ở trạng thái chưa hoạt động. Khi đã thu tối thiểu 20% phí ban đầu, bấm Kích hoạt để cửa hàng bắt đầu hoạt động.",
    fields: [
      { name: "application_id", label: "Hồ sơ đã duyệt", type: "select", required: true, options: available.map((item) => ({ value: item.id, label: `${item.proposed_store_name} — ${item.applicant_name}` })) },
      { name: "contract_no", label: "Số hợp đồng", required: true, value: `HD-${Date.now()}` },
      { name: "signed_date", label: "Ngày ký", type: "date", value: today() },
      { name: "effective_from", label: "Hiệu lực từ", type: "date", required: true, value: today() },
      { name: "effective_to", label: "Hiệu lực đến", type: "date", required: true, value: nextYear.toISOString().slice(0, 10) },
      { name: "royalty_rate", label: "Phí bản quyền (%)", type: "number", dataType: "number", required: true, value: 5, min: 0, max: 100, step: 0.01 },
      { name: "initial_franchise_fee", label: "Phí nhượng quyền ban đầu", type: "number", dataType: "number", required: true, value: 100000000, min: 0 },
      { name: "deposit_amount", label: "Tiền đặt cọc", type: "number", dataType: "number", required: true, value: 20000000, min: 0 },
      { name: "system_fee", label: "Phí hệ thống/tháng", type: "number", dataType: "number", required: true, value: 1000000, min: 0 },
      { name: "service_fee", label: "Phí dịch vụ/tháng", type: "number", dataType: "number", required: true, value: 2000000, min: 0 },
    ],
    submitText: "Lập hợp đồng",
    onSubmit: (values) => submitCreation("/api/v1/contracts", values, "Đã lập hợp đồng và tạo cửa hàng (chưa hoạt động)."),
  });
}

function openContractTransaction(contract) {
  openDialog({
    title: `Ghi nhận phí — ${contract.contract_no}`,
    fields: [
      { name: "transaction_type", label: "Loại giao dịch", type: "select", required: true, options: [
        { value: "INITIAL_FEE_PAYMENT", label: "Thanh toán phí ban đầu" },
        { value: "DEPOSIT_PAYMENT", label: "Thanh toán tiền đặt cọc" },
      ] },
      { name: "amount", label: "Số tiền", type: "number", dataType: "number", required: true, min: 1 },
      { name: "transaction_date", label: "Ngày giao dịch", type: "date", required: true, value: today() },
      { name: "reference_no", label: "Mã tham chiếu" },
      { name: "note", label: "Ghi chú", type: "textarea" },
    ],
    submitText: "Ghi nhận",
    onSubmit: (values) => submitCreation(`/api/v1/contracts/${contract.id}/financial-transactions`, values, "Đã ghi nhận giao dịch hợp đồng."),
  });
}

function openCreatePromotion() {
  const nextWeek = new Date();
  nextWeek.setDate(nextWeek.getDate() + 7);
  openDialog({
    title: "Tạo chương trình khuyến mãi",
    description: "Thương hiệu chịu 100% chi phí khuyến mãi: toàn bộ tiền giảm giá được trừ vào hóa đơn phí của cửa hàng.",
    fields: [
      { name: "name", label: "Tên chương trình", required: true },
      { name: "description", label: "Mô tả", type: "textarea" },
      { name: "discount_type", label: "Loại giảm giá", type: "select", required: true, options: [
        { value: "FIXED_AMOUNT", label: "Số tiền cố định" },
        { value: "PERCENTAGE", label: "Phần trăm" },
      ] },
      { name: "discount_value", label: "Mức giảm", type: "number", dataType: "number", required: true, min: 0.01, step: 0.01 },
      { name: "start_date", label: "Ngày bắt đầu", type: "date", required: true, value: today() },
      { name: "end_date", label: "Ngày kết thúc", type: "date", required: true, value: nextWeek.toISOString().slice(0, 10) },
    ],
    submitText: "Tạo khuyến mãi",
    onSubmit: (values) => submitCreation("/api/v1/promotions", { ...values, scope: "ALL_STORES", store_ids: [] }, "Khuyến mãi nháp đã được tạo."),
  });
}

async function openCreateRevenue() {
  const [stores, promotions] = await Promise.all([fetchPage("stores", { status: "ACTIVE" }), fetchPage("promotions", { status: "ACTIVE" })]);
  if (!stores.ok) return showToast(resultMessage(stores), true);
  if (!stores.data.items.length) return showToast("Bạn chưa có cửa hàng đang hoạt động.", true);
  const activePromotions = promotions.ok ? promotions.data.items : [];
  openDialog({
    title: "Ghi nhận doanh thu ngày",
    description: "Doanh thu được lưu nháp trước khi gửi Kế toán duyệt. Tiền giảm giá khuyến mãi do thương hiệu chịu và được trừ vào hóa đơn tháng.",
    fields: [
      { name: "store_id", label: "Cửa hàng", type: "select", required: true, options: stores.data.items.map((item) => ({ value: item.id, label: `${item.code} — ${item.name}` })) },
      { name: "business_date", label: "Ngày kinh doanh", type: "date", required: true, value: today() },
      { name: "gross_revenue", label: "Doanh thu gộp", type: "number", dataType: "number", required: true, min: 0 },
      { name: "promotion_id", label: "Khuyến mãi áp dụng", type: "select", options: activePromotions.map((item) => ({ value: item.id, label: item.name })) },
      { name: "discount_amount", label: "Số tiền giảm giá", type: "number", dataType: "number", value: 0, min: 0 },
      { name: "note", label: "Ghi chú", type: "textarea" },
    ],
    submitText: "Lưu doanh thu",
    onSubmit: (values) => {
      const { promotion_id, discount_amount, ...payload } = values;
      payload.promotion_details = promotion_id ? [{ promotion_id, discount_amount: discount_amount || 0 }] : [];
      return submitCreation("/api/v1/revenues", payload, "Doanh thu nháp đã được lưu.");
    },
  });
}

async function openGenerateInvoice() {
  const stores = await fetchPage("stores", { status: "ACTIVE" });
  if (!stores.ok) return showToast(resultMessage(stores), true);
  if (!stores.data.items.length) return showToast("Không có cửa hàng đang hoạt động.", true);
  openDialog({
    title: "Lập hóa đơn phí nhượng quyền",
    description: "Hệ thống tự tổng hợp doanh thu đã duyệt, tính phí bản quyền trên doanh thu gộp và trừ toàn bộ tiền giảm giá khuyến mãi (thương hiệu chịu).",
    fields: [
      { name: "store_id", label: "Cửa hàng", type: "select", required: true, options: stores.data.items.map((item) => ({ value: item.id, label: `${item.code} — ${item.name}` })) },
      { name: "invoice_no", label: "Số hóa đơn", required: true, value: `INV-${Date.now()}` },
      { name: "period_month", label: "Kỳ hóa đơn", type: "date", required: true, value: monthStart() },
      { name: "vat_rate", label: "Thuế VAT (%)", type: "number", dataType: "number", required: true, value: 10, min: 0, max: 100 },
    ],
    submitText: "Tạo hóa đơn",
    onSubmit: (values) => submitCreation("/api/v1/invoices/generate", values, "Hóa đơn nháp đã được tạo."),
  });
}

function openPayment(invoice) {
  openDialog({
    title: `Ghi nhận thanh toán — ${invoice.invoice_no}`,
    description: `Công nợ hiện tại: ${displayValue("outstanding_amount", invoice.outstanding_amount)}`,
    fields: [
      { name: "payment_no", label: "Mã thanh toán", required: true, value: `PAY-${Date.now()}` },
      { name: "amount", label: "Số tiền", type: "number", dataType: "number", required: true, min: 1, max: Number(invoice.outstanding_amount) },
      { name: "payment_date", label: "Ngày thanh toán", type: "date", required: true, value: today() },
      { name: "method", label: "Phương thức", type: "select", required: true, options: [
        { value: "BANK_TRANSFER", label: "Chuyển khoản" },
        { value: "CASH", label: "Tiền mặt" },
        { value: "OTHER", label: "Khác" },
      ] },
      { name: "reference_no", label: "Mã tham chiếu" },
    ],
    submitText: "Ghi nhận thanh toán",
    onSubmit: (values) => submitCreation(`/api/v1/invoices/${invoice.id}/payments`, values, "Thanh toán đã được ghi nhận."),
  });
}

function openReasonAction(title, label, required, submit) {
  openDialog({
    title,
    fields: [{ name: "value", label, type: "textarea", required }],
    onSubmit: ({ value }) => submit(value),
  });
}

async function downloadProtected(path, filename) {
  try {
    const result = await apiRequest(path);
    if (!result.ok) throw new Error(resultMessage(result));
    const url = URL.createObjectURL(result.data);
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    document.body.append(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
    showToast("Đã tải tệp.");
  } catch (error) {
    showToast(error.message, true);
  }
}

async function importRevenueFile(file) {
  const data = new FormData();
  data.append("file", file);
  try {
    const result = await apiRequest("/api/v1/revenues/import", { method: "POST", body: data });
    if (!result.ok) throw new Error(resultMessage(result));
    const failed = result.data.errors || [];
    const detail = failed.length ? ` Lỗi: ${failed.slice(0, 3).map((item) => `dòng ${item.row} - ${translateError(item.error)}`).join("; ")}` : "";
    showToast(`Đã nhập ${result.data.success_rows}/${result.data.total_rows} dòng.${detail}`, failed.length > 0);
    await loadResource();
  } catch (error) {
    showToast(error.message, true);
  } finally {
    element("revenue-file").value = "";
  }
}

async function loadDashboard() {
  const keys = ["applications", "stores", "contracts", "revenues", "invoices", "payments"];
  const results = await Promise.all(keys.map(async (key) => {
    try {
      const result = await fetchPage(key);
      return [key, result.ok ? result.data : { items: [], total: 0 }];
    } catch {
      return [key, { items: [], total: 0 }];
    }
  }));
  const data = Object.fromEntries(results);
  const cards = element("summary-cards");
  cards.replaceChildren();
  keys.slice(0, 4).forEach((key) => {
    const card = document.createElement("article");
    card.className = "panel summary-card";
    const label = document.createElement("span");
    label.textContent = resources[key].title;
    const value = document.createElement("strong");
    value.textContent = data[key].total;
    card.append(label, value);
    cards.append(card);
  });

  const tasks = [];
  if (hasRole("ADMIN")) {
    const pendingApps = data.applications.items.filter((item) => ["PENDING", "UNDER_REVIEW"].includes(item.status)).length;
    const draftContracts = data.contracts.items.filter((item) => item.status === "DRAFT").length;
    if (pendingApps) tasks.push(`${pendingApps} hồ sơ đang chờ xử lý`);
    if (draftContracts) tasks.push(`${draftContracts} hợp đồng chưa kích hoạt`);
  }
  if (hasRole("ACCOUNTANT")) {
    const submitted = data.revenues.items.filter((item) => item.status === "SUBMITTED").length;
    const draftInvoices = data.invoices.items.filter((item) => item.status === "DRAFT").length;
    if (submitted) tasks.push(`${submitted} báo cáo doanh thu chờ duyệt`);
    if (draftInvoices) tasks.push(`${draftInvoices} hóa đơn chờ phát hành`);
  }
  if (hasRole("STORE_OWNER")) {
    const drafts = data.revenues.items.filter((item) => ["DRAFT", "REJECTED"].includes(item.status)).length;
    const outstanding = data.invoices.items.filter((item) => ["ISSUED", "PARTIALLY_PAID", "OVERDUE"].includes(item.status)).length;
    if (drafts) tasks.push(`${drafts} doanh thu cần gửi hoặc chỉnh sửa`);
    if (outstanding) tasks.push(`${outstanding} hóa đơn còn công nợ`);
  }
  renderQueue(element("work-queue"), tasks, "Không có công việc tồn đọng.");

  try {
    const notifications = await fetchPage("notifications");
    const unread = notifications.ok ? notifications.data.items.filter((item) => !item.read_at).slice(0, 5).map((item) => item.title) : [];
    renderQueue(element("recent-notifications"), unread, "Không có thông báo mới.");
  } catch {
    renderQueue(element("recent-notifications"), [], "Không tải được thông báo.");
  }
}

function renderQueue(container, items, emptyText) {
  container.replaceChildren();
  if (!items.length) {
    const empty = document.createElement("p");
    empty.className = "muted";
    empty.textContent = emptyText;
    container.append(empty);
    return;
  }
  items.forEach((text) => {
    const item = document.createElement("div");
    item.className = "queue-item";
    item.textContent = text;
    container.append(item);
  });
}

function renderStandaloneTable(container, rows) {
  container.replaceChildren();
  if (!rows.length) {
    const empty = document.createElement("p");
    empty.className = "empty";
    empty.textContent = "Không có dữ liệu trong khoảng thời gian này.";
    container.append(empty);
    return;
  }
  const keys = Object.keys(rows[0]).filter((key) => key !== "store_id");
  const table = document.createElement("table");
  const head = document.createElement("thead");
  const hr = document.createElement("tr");
  keys.forEach((key) => { const th = document.createElement("th"); th.textContent = labels[key] || key; hr.append(th); });
  head.append(hr);
  const body = document.createElement("tbody");
  rows.forEach((row) => {
    const tr = document.createElement("tr");
    keys.forEach((key) => { const td = document.createElement("td"); td.textContent = displayValue(key, row[key], row); tr.append(td); });
    body.append(tr);
  });
  table.append(head, body);
  container.append(table);
}

async function loadReport(event) {
  event.preventDefault();
  const from = element("period-from").value;
  const to = element("period-to").value;
  try {
    const result = await apiRequest(`/api/v1/reports/financial-summary?period_from=${from}&period_to=${to}`);
    if (!result.ok) throw new Error(resultMessage(result));
    renderStandaloneTable(element("report-output"), result.data);
  } catch (error) {
    showToast(error.message, true);
  }
}

async function exportReport(format) {
  const from = element("period-from").value;
  const to = element("period-to").value;
  if (!from || !to) return showToast("Hãy chọn khoảng thời gian.", true);
  await downloadProtected(`/api/v1/reports/financial-summary/export?period_from=${from}&period_to=${to}&format=${format}`, `bao-cao-tai-chinh.${format}`);
}

function bindEvents() {
  element("login-form").addEventListener("submit", handleLogin);
  element("register-button").addEventListener("click", openRegister);
  element("logout-button").addEventListener("click", handleLogout);
  document.querySelectorAll(".demo-user").forEach((button) => button.addEventListener("click", () => {
    element("email").value = button.dataset.email;
    element("password").value = "Admin@123";
  }));
  document.querySelectorAll(".nav-item").forEach((button) => button.addEventListener("click", () => openView(button.dataset.view)));
  element("refresh-dashboard").addEventListener("click", loadDashboard);
  element("refresh-resource").addEventListener("click", loadResource);
  element("filter-form").addEventListener("submit", (event) => { event.preventDefault(); state.page = 1; loadResource(); });
  element("previous-page").addEventListener("click", () => { if (state.page > 1) { state.page -= 1; loadResource(); } });
  element("next-page").addEventListener("click", () => { if (state.page * state.pageSize < state.total) { state.page += 1; loadResource(); } });
  element("import-revenue").addEventListener("click", () => element("revenue-file").click());
  element("revenue-file").addEventListener("change", (event) => { if (event.target.files[0]) importRevenueFile(event.target.files[0]); });
  element("report-form").addEventListener("submit", loadReport);
  document.querySelectorAll(".export-button").forEach((button) => button.addEventListener("click", () => exportReport(button.dataset.format)));
  element("operation-form").addEventListener("submit", submitDialog);
  element("close-dialog").addEventListener("click", closeDialog);
  element("cancel-dialog").addEventListener("click", closeDialog);
}

async function initialize() {
  const date = new Date();
  element("period-to").value = today();
  element("period-from").value = `${date.getFullYear()}-01-01`;
  bindEvents();
  await checkHealth();
  if (state.accessToken) {
    try {
      await loadCurrentUser();
      await openView("dashboard");
      return;
    } catch {
      setSession("", "");
    }
  }
  showLogin();
}

initialize();
