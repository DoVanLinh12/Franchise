# Use cases và flow hệ thống

## Onboarding

```text
Register/Login → Submit Application → Admin Review → Approve
→ Create Contract DRAFT from the approved application
   → Store created automatically as INACTIVE (code CHxxxx, name/address from the application,
     owner = applicant, role STORE_OWNER)
→ Record >=20% Initial Fee → Activate Contract → Store ACTIVE
```

## Revenue

```text
Owner saves DRAFT → Submit → Accountant Approve
                         ↘ Reject → Owner edits → Submit again
Approved → request adjustment → version snapshot → Owner edits → re-approve
```

## Monthly billing

```text
Approved daily Revenue
→ Monthly Gross/Discount/Net
→ Royalty on Gross
→ + fixed fees + adjustments
→ - Brand Support - Credit
→ taxable >= 0 → VAT → Invoice
```

Nếu kết quả trước VAT âm, Invoice bằng 0 và phần dư thành Credit kỳ sau.

## Payment

```text
Invoice ISSUED → partial Payment → PARTIALLY_PAID
→ paid fully → PAID
→ due date passed with balance → OVERDUE
Payment entered incorrectly → REVERSED → recalculate Invoice status
```

## Background operations

Celery beat gọi job tạo Late Revenue và Overdue Invoice notification. Reset
password enqueue email tới MailHog khi stack `full` đang chạy.
