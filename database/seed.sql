-- Dữ liệu mẫu local cho hệ thống Franchise Management.
-- Tất cả tài khoản mẫu dùng mật khẩu: Admin@123
-- Script có thể chạy lại nhiều lần mà không tạo bản ghi trùng.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Người dùng và vai trò
-- ---------------------------------------------------------------------------
INSERT INTO app.users (id, email, password_hash, full_name, phone, status)
VALUES
    ('90000000-0000-0000-0000-000000000001', 'admin@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Nguyễn Hoàng Nam', '0901234567', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000002', 'owner@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Lê Minh Anh', '0912345678', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000003', 'accountant@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Trần Thu Hà', '0987654321', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000004', 'pham.quang.huy@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Phạm Quang Huy', '0903456789', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000005', 'vu.ngoc.lan@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Vũ Ngọc Lan', '0934567890', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000006', 'do.thanh.tung@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Đỗ Thanh Tùng', '0945678901', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000007', 'nguyen.thao.vy@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Nguyễn Thảo Vy', '0966789012', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000008', 'hoang.gia.bao@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Hoàng Gia Bảo', '0977890123', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000009', 'bui.khanh.linh@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Bùi Khánh Linh', '0888901234', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000010', 'dang.tuan.kiet@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Đặng Tuấn Kiệt', '0899012345', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000011', 'mai.phuong.thao@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Mai Phương Thảo', '0901122334', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000012', 'truong.duc.long@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Trương Đức Long', '0912233445', 'ACTIVE'),
    ('90000000-0000-0000-0000-000000000013', 'ngo.hai.yen@franchise.local',
     '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
     'Ngô Hải Yến', '0923344556', 'ACTIVE')
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email, password_hash = EXCLUDED.password_hash,
    full_name = EXCLUDED.full_name, phone = EXCLUDED.phone,
    status = EXCLUDED.status, updated_at = now(), deleted_at = NULL;

INSERT INTO app.user_roles (user_id, role_id)
SELECT mapping.user_id, r.id
FROM (VALUES
    ('90000000-0000-0000-0000-000000000001'::uuid, 'ADMIN'),
    ('90000000-0000-0000-0000-000000000002'::uuid, 'STORE_OWNER'),
    ('90000000-0000-0000-0000-000000000003'::uuid, 'ACCOUNTANT'),
    ('90000000-0000-0000-0000-000000000004'::uuid, 'STORE_OWNER'),
    ('90000000-0000-0000-0000-000000000005'::uuid, 'STORE_OWNER'),
    ('90000000-0000-0000-0000-000000000006'::uuid, 'STORE_OWNER'),
    ('90000000-0000-0000-0000-000000000007'::uuid, 'STORE_OWNER'),
    ('90000000-0000-0000-0000-000000000008'::uuid, 'STORE_OWNER'),
    ('90000000-0000-0000-0000-000000000009'::uuid, 'STORE_OWNER')
) AS mapping(user_id, role_code)
JOIN app.roles r ON r.code = mapping.role_code
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Hồ sơ đăng ký nhượng quyền
-- ---------------------------------------------------------------------------
INSERT INTO app.franchise_applications (
    id, applicant_id, applicant_name, email, phone,
    proposed_store_name, proposed_address, proposed_area, investment_budget,
    note, status, review_started_by, review_started_at, review_note,
    reviewed_by, reviewed_at, withdrawn_by, withdrawn_at, withdrawal_reason,
    converted_at, created_at, updated_at
)
VALUES
    ('91000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002',
     'Lê Minh Anh', 'owner@franchise.local', '0912345678', 'Mộc Miên Coffee Hoàn Kiếm',
     '38 Hàng Bông, phường Hàng Bông, quận Hoàn Kiếm, Hà Nội', 118, 1850000000,
     'Mặt bằng góc hai mặt tiền, gần khu phố đi bộ.', 'APPROVED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '910 days',
     'Mặt bằng và phương án tài chính đạt yêu cầu.',
     '90000000-0000-0000-0000-000000000001', current_date - interval '905 days', NULL, NULL, NULL,
     current_date - interval '900 days', current_date - interval '925 days', current_date - interval '900 days'),
    ('91000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000004',
     'Phạm Quang Huy', 'pham.quang.huy@franchise.local', '0903456789', 'Mộc Miên Coffee Cầu Giấy',
     '126 Trần Thái Tông, phường Dịch Vọng Hậu, quận Cầu Giấy, Hà Nội', 145, 2200000000,
     'Khu văn phòng đông, có chỗ để xe máy.', 'APPROVED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '790 days',
     'Chủ đầu tư có kinh nghiệm vận hành F&B.',
     '90000000-0000-0000-0000-000000000001', current_date - interval '785 days', NULL, NULL, NULL,
     current_date - interval '780 days', current_date - interval '805 days', current_date - interval '780 days'),
    ('91000000-0000-0000-0000-000000000003', '90000000-0000-0000-0000-000000000005',
     'Vũ Ngọc Lan', 'vu.ngoc.lan@franchise.local', '0934567890', 'Mộc Miên Coffee Bạch Mai',
     '215 Bạch Mai, phường Cầu Dền, quận Hai Bà Trưng, Hà Nội', 105, 1650000000,
     'Tầng một nhà phố, khu dân cư ổn định.', 'APPROVED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '670 days',
     'Đạt tiêu chuẩn vị trí và nhận diện.',
     '90000000-0000-0000-0000-000000000001', current_date - interval '665 days', NULL, NULL, NULL,
     current_date - interval '660 days', current_date - interval '682 days', current_date - interval '660 days'),
    ('91000000-0000-0000-0000-000000000004', '90000000-0000-0000-0000-000000000006',
     'Đỗ Thanh Tùng', 'do.thanh.tung@franchise.local', '0945678901', 'Mộc Miên Coffee Hải Châu',
     '84 Nguyễn Văn Linh, phường Nam Dương, quận Hải Châu, Đà Nẵng', 132, 2050000000,
     'Nằm trên trục đường sân bay vào trung tâm thành phố.', 'APPROVED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '550 days',
     'Lưu lượng khách tốt, kế hoạch nhân sự phù hợp.',
     '90000000-0000-0000-0000-000000000001', current_date - interval '545 days', NULL, NULL, NULL,
     current_date - interval '540 days', current_date - interval '562 days', current_date - interval '540 days'),
    ('91000000-0000-0000-0000-000000000005', '90000000-0000-0000-0000-000000000007',
     'Nguyễn Thảo Vy', 'nguyen.thao.vy@franchise.local', '0966789012', 'Mộc Miên Coffee Nguyễn Huệ',
     '112 Nguyễn Huệ, phường Sài Gòn, Thành phố Hồ Chí Minh', 168, 2800000000,
     'Mô hình cửa hàng flagship tại khu trung tâm.', 'APPROVED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '430 days',
     'Phương án đầu tư và thiết kế được phê duyệt.',
     '90000000-0000-0000-0000-000000000001', current_date - interval '425 days', NULL, NULL, NULL,
     current_date - interval '420 days', current_date - interval '445 days', current_date - interval '420 days'),
    ('91000000-0000-0000-0000-000000000006', '90000000-0000-0000-0000-000000000008',
     'Hoàng Gia Bảo', 'hoang.gia.bao@franchise.local', '0977890123', 'Mộc Miên Coffee Thảo Điền',
     '46 Xuân Thủy, phường Thảo Điền, thành phố Thủ Đức, Thành phố Hồ Chí Minh', 155, 2450000000,
     'Khu dân cư có tỷ lệ khách quốc tế cao.', 'APPROVED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '370 days',
     'Đủ điều kiện thương mại và vận hành.',
     '90000000-0000-0000-0000-000000000001', current_date - interval '365 days', NULL, NULL, NULL,
     current_date - interval '360 days', current_date - interval '382 days', current_date - interval '360 days'),
    ('91000000-0000-0000-0000-000000000007', '90000000-0000-0000-0000-000000000009',
     'Bùi Khánh Linh', 'bui.khanh.linh@franchise.local', '0888901234', 'Mộc Miên Coffee Hạ Long',
     '128 đường Hạ Long, phường Bãi Cháy, thành phố Hạ Long, Quảng Ninh', 138, 2100000000,
     'Cửa hàng hướng biển, dự kiến khai trương đầu quý tới.', 'APPROVED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '70 days',
     'Đã duyệt, đang hoàn thiện thiết kế và thi công.',
     '90000000-0000-0000-0000-000000000001', current_date - interval '65 days', NULL, NULL, NULL,
     current_date - interval '60 days', current_date - interval '82 days', current_date - interval '60 days'),
    ('91000000-0000-0000-0000-000000000008', '90000000-0000-0000-0000-000000000009',
     'Bùi Khánh Linh', 'bui.khanh.linh@franchise.local', '0888901234', 'Mộc Miên Coffee Ninh Kiều',
     '72 Hai Bà Trưng, phường Tân An, quận Ninh Kiều, Cần Thơ', 125, 1900000000,
     'Điểm bán đầu tiên tại khu vực Tây Nam Bộ.', 'APPROVED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '310 days',
     'Đã hoàn tất đánh giá thị trường địa phương.',
     '90000000-0000-0000-0000-000000000001', current_date - interval '305 days', NULL, NULL, NULL,
     current_date - interval '300 days', current_date - interval '322 days', current_date - interval '300 days'),
    ('91000000-0000-0000-0000-000000000009', '90000000-0000-0000-0000-000000000010',
     'Đặng Tuấn Kiệt', 'dang.tuan.kiet@franchise.local', '0899012345', 'Mộc Miên Coffee Vinh',
     '16 Lê Lợi, phường Hưng Bình, thành phố Vinh, Nghệ An', 120, 1750000000,
     'Đề nghị khảo sát lưu lượng khách trong bán kính 2 km.', 'PENDING',
     NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
     current_date - interval '3 days', current_date - interval '3 days'),
    ('91000000-0000-0000-0000-000000000010', '90000000-0000-0000-0000-000000000011',
     'Mai Phương Thảo', 'mai.phuong.thao@franchise.local', '0901122334', 'Mộc Miên Coffee Quy Nhơn',
     '95 An Dương Vương, phường Nguyễn Văn Cừ, thành phố Quy Nhơn, Bình Định', 142, 2150000000,
     'Đã cung cấp hồ sơ tài chính, chờ thẩm định mặt bằng.', 'UNDER_REVIEW',
     '90000000-0000-0000-0000-000000000001', current_date - interval '2 days',
     'Đang xác minh hợp đồng thuê mặt bằng.', NULL, NULL, NULL, NULL, NULL, NULL,
     current_date - interval '6 days', current_date - interval '2 days'),
    ('91000000-0000-0000-0000-000000000011', '90000000-0000-0000-0000-000000000012',
     'Trương Đức Long', 'truong.duc.long@franchise.local', '0912233445', 'Mộc Miên Coffee Biên Hòa',
     '204 Phạm Văn Thuận, phường Tân Tiến, thành phố Biên Hòa, Đồng Nai', 82, 980000000,
     'Diện tích thực tế thấp hơn tiêu chuẩn mô hình.', 'REJECTED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '14 days',
     'Mặt bằng chưa đạt diện tích tối thiểu và thiếu khu vực đỗ xe.',
     '90000000-0000-0000-0000-000000000001', current_date - interval '10 days', NULL, NULL, NULL, NULL,
     current_date - interval '20 days', current_date - interval '10 days'),
    ('91000000-0000-0000-0000-000000000012', '90000000-0000-0000-0000-000000000013',
     'Ngô Hải Yến', 'ngo.hai.yen@franchise.local', '0923344556', 'Mộc Miên Coffee Huế',
     '41 Lê Lợi, phường Phú Hội, thành phố Huế, Thừa Thiên Huế', 130, 1950000000,
     'Hồ sơ đạt yêu cầu, đang chờ ký hợp đồng thuê.', 'APPROVED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '12 days',
     'Đủ điều kiện mở cửa hàng, chờ hoàn thiện giấy tờ mặt bằng.',
     '90000000-0000-0000-0000-000000000001', current_date - interval '7 days', NULL, NULL, NULL, NULL,
     current_date - interval '18 days', current_date - interval '7 days')
ON CONFLICT (id) DO UPDATE SET
    applicant_name = EXCLUDED.applicant_name, email = EXCLUDED.email,
    phone = EXCLUDED.phone, proposed_store_name = EXCLUDED.proposed_store_name,
    proposed_address = EXCLUDED.proposed_address, proposed_area = EXCLUDED.proposed_area,
    investment_budget = EXCLUDED.investment_budget, note = EXCLUDED.note,
    status = EXCLUDED.status, review_started_by = EXCLUDED.review_started_by,
    review_started_at = EXCLUDED.review_started_at, review_note = EXCLUDED.review_note,
    reviewed_by = EXCLUDED.reviewed_by, reviewed_at = EXCLUDED.reviewed_at,
    converted_at = EXCLUDED.converted_at, updated_at = EXCLUDED.updated_at,
    deleted_at = NULL;

-- ---------------------------------------------------------------------------
-- 3. Cửa hàng và hợp đồng
-- ---------------------------------------------------------------------------
INSERT INTO app.stores (
    id, code, name, owner_id, application_id, address, phone, email,
    status, activated_at, closed_at, created_at, updated_at
)
VALUES
    ('92000000-0000-0000-0000-000000000001', 'HN-HK-001', 'Mộc Miên Coffee Hoàn Kiếm',
     '90000000-0000-0000-0000-000000000002', '91000000-0000-0000-0000-000000000001',
     '38 Hàng Bông, phường Hàng Bông, quận Hoàn Kiếm, Hà Nội', '02439361268', 'hoankiem@mocmien.local',
     'ACTIVE', current_date - interval '870 days', NULL, current_date - interval '900 days', current_date - interval '870 days'),
    ('92000000-0000-0000-0000-000000000002', 'HN-CG-002', 'Mộc Miên Coffee Cầu Giấy',
     '90000000-0000-0000-0000-000000000004', '91000000-0000-0000-0000-000000000002',
     '126 Trần Thái Tông, phường Dịch Vọng Hậu, quận Cầu Giấy, Hà Nội', '02437681226', 'caugiay@mocmien.local',
     'ACTIVE', current_date - interval '750 days', NULL, current_date - interval '780 days', current_date - interval '750 days'),
    ('92000000-0000-0000-0000-000000000003', 'HN-HBT-003', 'Mộc Miên Coffee Bạch Mai',
     '90000000-0000-0000-0000-000000000005', '91000000-0000-0000-0000-000000000003',
     '215 Bạch Mai, phường Cầu Dền, quận Hai Bà Trưng, Hà Nội', '02436281125', 'bachmai@mocmien.local',
     'ACTIVE', current_date - interval '630 days', NULL, current_date - interval '660 days', current_date - interval '630 days'),
    ('92000000-0000-0000-0000-000000000004', 'DN-HC-004', 'Mộc Miên Coffee Hải Châu',
     '90000000-0000-0000-0000-000000000006', '91000000-0000-0000-0000-000000000004',
     '84 Nguyễn Văn Linh, phường Nam Dương, quận Hải Châu, Đà Nẵng', '02363561284', 'haichau@mocmien.local',
     'ACTIVE', current_date - interval '510 days', NULL, current_date - interval '540 days', current_date - interval '510 days'),
    ('92000000-0000-0000-0000-000000000005', 'HCM-SG-005', 'Mộc Miên Coffee Nguyễn Huệ',
     '90000000-0000-0000-0000-000000000007', '91000000-0000-0000-0000-000000000005',
     '112 Nguyễn Huệ, phường Sài Gòn, Thành phố Hồ Chí Minh', '02838221112', 'nguyenhue@mocmien.local',
     'ACTIVE', current_date - interval '390 days', NULL, current_date - interval '420 days', current_date - interval '390 days'),
    ('92000000-0000-0000-0000-000000000006', 'HCM-TD-006', 'Mộc Miên Coffee Thảo Điền',
     '90000000-0000-0000-0000-000000000008', '91000000-0000-0000-0000-000000000006',
     '46 Xuân Thủy, phường Thảo Điền, thành phố Thủ Đức, Thành phố Hồ Chí Minh', '02837441246', 'thaodien@mocmien.local',
     'ACTIVE', current_date - interval '330 days', NULL, current_date - interval '360 days', current_date - interval '330 days'),
    ('92000000-0000-0000-0000-000000000007', 'QN-HL-007', 'Mộc Miên Coffee Hạ Long',
     '90000000-0000-0000-0000-000000000009', '91000000-0000-0000-0000-000000000007',
     '128 đường Hạ Long, phường Bãi Cháy, thành phố Hạ Long, Quảng Ninh', '02033841228', 'halong@mocmien.local',
     'INACTIVE', NULL, NULL, current_date - interval '60 days', current_date - interval '5 days'),
    ('92000000-0000-0000-0000-000000000008', 'CT-NK-008', 'Mộc Miên Coffee Ninh Kiều',
     '90000000-0000-0000-0000-000000000009', '91000000-0000-0000-0000-000000000008',
     '72 Hai Bà Trưng, phường Tân An, quận Ninh Kiều, Cần Thơ', '02923811272', 'ninhkieu@mocmien.local',
     'SUSPENDED', current_date - interval '270 days', NULL, current_date - interval '300 days', current_date - interval '12 days')
ON CONFLICT (id) DO UPDATE SET
    code = EXCLUDED.code, name = EXCLUDED.name, owner_id = EXCLUDED.owner_id,
    application_id = EXCLUDED.application_id, address = EXCLUDED.address,
    phone = EXCLUDED.phone, email = EXCLUDED.email, status = EXCLUDED.status,
    activated_at = EXCLUDED.activated_at, closed_at = EXCLUDED.closed_at,
    updated_at = EXCLUDED.updated_at, deleted_at = NULL;

INSERT INTO app.contracts (
    id, contract_no, store_id, signed_date, effective_from, effective_to,
    royalty_rate, initial_franchise_fee, deposit_amount, system_fee,
    service_fee, status, created_at, updated_at
)
SELECT
    ('93000000-0000-0000-0000-' || lpad(store_no::text, 12, '0'))::uuid,
    contract_no,
    ('92000000-0000-0000-0000-' || lpad(store_no::text, 12, '0'))::uuid,
    signed_date, effective_from, effective_to, royalty_rate,
    initial_fee, deposit, system_fee, service_fee, status,
    signed_date::timestamptz - interval '7 days', signed_date::timestamptz
FROM (VALUES
    (1, 'FRC-2024-HN-HK-001', current_date - 880, current_date - 870, current_date + 590, 5.0, 180000000, 50000000, 1500000, 2500000, 'ACTIVE'),
    (2, 'FRC-2024-HN-CG-002', current_date - 760, current_date - 750, current_date + 710, 5.0, 180000000, 50000000, 1500000, 2500000, 'ACTIVE'),
    (3, 'FRC-2025-HN-HBT-003', current_date - 640, current_date - 630, current_date + 830, 5.5, 165000000, 45000000, 1500000, 2200000, 'ACTIVE'),
    (4, 'FRC-2025-DN-HC-004', current_date - 520, current_date - 510, current_date + 950, 5.0, 175000000, 50000000, 1400000, 2300000, 'ACTIVE'),
    (5, 'FRC-2025-HCM-SG-005', current_date - 400, current_date - 390, current_date + 1070, 6.0, 220000000, 70000000, 1800000, 3000000, 'ACTIVE'),
    (6, 'FRC-2025-HCM-TD-006', current_date - 340, current_date - 330, current_date + 1130, 5.5, 200000000, 60000000, 1700000, 2800000, 'ACTIVE'),
    (7, 'FRC-2026-QN-HL-007', current_date - 20, current_date + 20, current_date + 1480, 5.0, 185000000, 55000000, 1500000, 2500000, 'DRAFT'),
    (8, 'FRC-2025-CT-NK-008', current_date - 280, current_date - 270, current_date + 1190, 5.0, 175000000, 50000000, 1400000, 2300000, 'ACTIVE')
) AS c(store_no, contract_no, signed_date, effective_from, effective_to,
       royalty_rate, initial_fee, deposit, system_fee, service_fee, status)
ON CONFLICT (id) DO UPDATE SET
    contract_no = EXCLUDED.contract_no, signed_date = EXCLUDED.signed_date,
    effective_from = EXCLUDED.effective_from, effective_to = EXCLUDED.effective_to,
    royalty_rate = EXCLUDED.royalty_rate,
    initial_franchise_fee = EXCLUDED.initial_franchise_fee,
    deposit_amount = EXCLUDED.deposit_amount, system_fee = EXCLUDED.system_fee,
    service_fee = EXCLUDED.service_fee, status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at;

INSERT INTO app.contract_financial_transactions (
    id, contract_id, transaction_type, amount, transaction_date,
    reference_no, note, recorded_by
)
SELECT
    md5('contract-payment:' || c.id::text || ':' || tx.transaction_type)::uuid,
    c.id, tx.transaction_type,
    CASE tx.transaction_type WHEN 'INITIAL_FEE_PAYMENT'
         THEN c.initial_franchise_fee ELSE c.deposit_amount END,
    c.signed_date,
    'UNC-' || replace(c.contract_no, 'FRC-', '') || '-' || tx.reference_suffix,
    CASE tx.transaction_type WHEN 'INITIAL_FEE_PAYMENT'
         THEN 'Thanh toán phí nhượng quyền ban đầu'
         ELSE 'Ký quỹ bảo đảm thực hiện hợp đồng' END,
    '90000000-0000-0000-0000-000000000003'
FROM app.contracts c
CROSS JOIN (VALUES ('INITIAL_FEE_PAYMENT', 'PNT'), ('DEPOSIT_PAYMENT', 'DEP'))
    AS tx(transaction_type, reference_suffix)
WHERE c.id IN (
    SELECT ('93000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid
    FROM generate_series(1, 6) n
)
ON CONFLICT (id) DO UPDATE SET
    amount = EXCLUDED.amount, transaction_date = EXCLUDED.transaction_date,
    reference_no = EXCLUDED.reference_no, note = EXCLUDED.note;

-- ---------------------------------------------------------------------------
-- 4. Chương trình khuyến mãi
-- ---------------------------------------------------------------------------
INSERT INTO app.promotions (
    id, name, description, discount_type, discount_value,
    start_date, end_date, scope, funding_type,
    brand_share_percent, store_share_percent, status, created_by,
    created_at, updated_at
)
VALUES
    ('94000000-0000-0000-0000-000000000001', 'Trung thu đoàn viên 2026',
     'Giảm 15% cho hóa đơn đồ uống từ 150.000 đồng trong dịp Trung thu.',
     'PERCENTAGE', 15, current_date - 10, current_date + 10,
     'ALL_STORES', 'SHARED', 60, 40, 'ACTIVE',
     '90000000-0000-0000-0000-000000000001', current_date - interval '25 days', current_date - interval '10 days'),
    ('94000000-0000-0000-0000-000000000002', 'Cà phê sáng - Năng lượng mới',
     'Giảm 20.000 đồng cho combo bánh và cà phê trước 09:30.',
     'FIXED_AMOUNT', 20000, current_date + 15, current_date + 45,
     'ALL_STORES', 'BRAND', 100, 0, 'DRAFT',
     '90000000-0000-0000-0000-000000000001', current_date - interval '4 days', current_date - interval '4 days'),
    ('94000000-0000-0000-0000-000000000003', 'Hè rực rỡ 2026',
     'Ưu đãi 10% cho nhóm khách từ bốn người trong mùa du lịch hè.',
     'PERCENTAGE', 10, current_date - 100, current_date - 40,
     'ALL_STORES', 'SHARED', 50, 50, 'EXPIRED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '120 days', current_date - interval '40 days'),
    ('94000000-0000-0000-0000-000000000004', 'Cuối tuần Sài Gòn',
     'Giảm 12% tại hai cửa hàng khu vực Thành phố Hồ Chí Minh.',
     'PERCENTAGE', 12, current_date - 7, current_date + 30,
     'SELECTED_STORES', 'STORE', 0, 100, 'ACTIVE',
     '90000000-0000-0000-0000-000000000001', current_date - interval '18 days', current_date - interval '7 days'),
    ('94000000-0000-0000-0000-000000000005', 'Đồng giá thức uống mùa mưa',
     'Chương trình dự kiến triển khai nhưng đã hủy do thay đổi kế hoạch sản phẩm.',
     'FIXED_AMOUNT', 25000, current_date - 25, current_date + 5,
     'ALL_STORES', 'BRAND', 100, 0, 'CANCELLED',
     '90000000-0000-0000-0000-000000000001', current_date - interval '40 days', current_date - interval '25 days')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    discount_type = EXCLUDED.discount_type, discount_value = EXCLUDED.discount_value,
    start_date = EXCLUDED.start_date, end_date = EXCLUDED.end_date,
    scope = EXCLUDED.scope, funding_type = EXCLUDED.funding_type,
    brand_share_percent = EXCLUDED.brand_share_percent,
    store_share_percent = EXCLUDED.store_share_percent, status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at, deleted_at = NULL;

INSERT INTO app.promotion_stores (promotion_id, store_id)
VALUES
    ('94000000-0000-0000-0000-000000000004', '92000000-0000-0000-0000-000000000005'),
    ('94000000-0000-0000-0000-000000000004', '92000000-0000-0000-0000-000000000006')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Doanh thu: 2.520 bản ghi theo ngày cho sáu cửa hàng đang hoạt động
-- ---------------------------------------------------------------------------
WITH store_seed AS (
    SELECT n AS store_no,
        ('92000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid AS store_id,
        CASE n
            WHEN 1 THEN '90000000-0000-0000-0000-000000000002'::uuid
            WHEN 2 THEN '90000000-0000-0000-0000-000000000004'::uuid
            WHEN 3 THEN '90000000-0000-0000-0000-000000000005'::uuid
            WHEN 4 THEN '90000000-0000-0000-0000-000000000006'::uuid
            WHEN 5 THEN '90000000-0000-0000-0000-000000000007'::uuid
            WHEN 6 THEN '90000000-0000-0000-0000-000000000008'::uuid
        END AS owner_id
    FROM generate_series(1, 6) n
), revenue_seed AS (
    SELECT s.store_no, s.store_id, s.owner_id, d.day::date AS business_date,
        round(7200000 + s.store_no * 1350000
            + extract(dow FROM d.day) * 310000
            + (extract(doy FROM d.day)::integer % 19) * 95000
            + CASE WHEN extract(isodow FROM d.day) IN (6, 7) THEN 2450000 ELSE 0 END
            + CASE WHEN extract(month FROM d.day) IN (1, 2, 6, 7, 12) THEN 1150000 ELSE 0 END
        )::numeric(18, 0) AS gross_revenue
    FROM store_seed s
    CROSS JOIN generate_series(current_date - interval '420 days',
        current_date - interval '1 day', interval '1 day') AS d(day)
)
INSERT INTO app.revenues (
    id, store_id, business_date, gross_revenue, promotion_discount,
    status, reported_by, reported_at, reviewed_by, reviewed_at, note,
    created_at, updated_at
)
SELECT
    md5('revenue:' || store_id::text || ':' || business_date::text)::uuid,
    store_id, business_date, gross_revenue,
    CASE WHEN extract(isodow FROM business_date) IN (5, 6, 7)
         THEN round(gross_revenue * 0.035) ELSE 0 END,
    'APPROVED', owner_id,
    business_date::timestamptz + interval '1 day 8 hours',
    '90000000-0000-0000-0000-000000000003',
    business_date::timestamptz + interval '1 day 10 hours',
    CASE WHEN extract(isodow FROM business_date) IN (6, 7)
         THEN 'Doanh thu cuối tuần đã đối soát với hệ thống bán hàng.'
         ELSE 'Doanh thu ngày đã đối soát.' END,
    business_date::timestamptz + interval '1 day 8 hours',
    business_date::timestamptz + interval '1 day 10 hours'
FROM revenue_seed
ON CONFLICT (store_id, business_date) DO UPDATE SET
    gross_revenue = EXCLUDED.gross_revenue,
    promotion_discount = EXCLUDED.promotion_discount,
    status = EXCLUDED.status, reported_by = EXCLUDED.reported_by,
    reported_at = EXCLUDED.reported_at, reviewed_by = EXCLUDED.reviewed_by,
    reviewed_at = EXCLUDED.reviewed_at, note = EXCLUDED.note,
    updated_at = EXCLUDED.updated_at;

UPDATE app.revenues
SET status = 'SUBMITTED', reviewed_by = NULL, reviewed_at = NULL,
    review_note = NULL, updated_at = now()
WHERE store_id = '92000000-0000-0000-0000-000000000001'
  AND business_date = current_date - 1;

UPDATE app.revenues
SET status = 'ADJUSTMENT_REQUESTED',
    adjustment_requested_by = '90000000-0000-0000-0000-000000000003',
    adjustment_requested_at = now() - interval '2 hours',
    adjustment_reason = 'Vui lòng bổ sung doanh thu từ đơn hàng giao qua ứng dụng.',
    reviewed_by = NULL, reviewed_at = NULL, updated_at = now()
WHERE store_id = '92000000-0000-0000-0000-000000000002'
  AND business_date = current_date - 1;

UPDATE app.revenues
SET status = 'DRAFT', reported_at = NULL, reviewed_by = NULL,
    reviewed_at = NULL, review_note = NULL, updated_at = now()
WHERE store_id = '92000000-0000-0000-0000-000000000003'
  AND business_date = current_date - 1;

UPDATE app.revenues
SET status = 'REJECTED', reviewed_by = '90000000-0000-0000-0000-000000000003',
    reviewed_at = now() - interval '1 day',
    review_note = 'Số tiền không khớp báo cáo chốt ca, cần kiểm tra lại.',
    updated_at = now()
WHERE store_id = '92000000-0000-0000-0000-000000000004'
  AND business_date = current_date - 2;

INSERT INTO app.revenue_promotion_details (
    id, revenue_id, promotion_id, discount_amount,
    brand_share_percent, store_share_percent,
    brand_support_amount, store_cost_amount, promotion_name_snapshot
)
SELECT
    md5('revenue-promotion:' || r.id::text || ':94000000-0000-0000-0000-000000000001')::uuid,
    r.id, '94000000-0000-0000-0000-000000000001', r.promotion_discount,
    60, 40, round(r.promotion_discount * 0.60),
    r.promotion_discount - round(r.promotion_discount * 0.60),
    'Trung thu đoàn viên 2026'
FROM app.revenues r
WHERE r.store_id IN (
    SELECT ('92000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid
    FROM generate_series(1, 6) n
)
  AND r.business_date BETWEEN current_date - 10 AND current_date - 1
  AND r.promotion_discount > 0
ON CONFLICT (revenue_id, promotion_id) DO UPDATE SET
    discount_amount = EXCLUDED.discount_amount,
    brand_support_amount = EXCLUDED.brand_support_amount,
    store_cost_amount = EXCLUDED.store_cost_amount,
    promotion_name_snapshot = EXCLUDED.promotion_name_snapshot;

INSERT INTO app.revenue_versions (
    revenue_id, version, snapshot, change_reason, changed_by
)
SELECT r.id, 1,
    jsonb_build_object('business_date', r.business_date,
        'gross_revenue', r.gross_revenue,
        'promotion_discount', r.promotion_discount, 'status', r.status),
    'Khởi tạo dữ liệu doanh thu đã đối soát', r.reported_by
FROM app.revenues r
WHERE r.store_id IN (
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002',
    '92000000-0000-0000-0000-000000000003',
    '92000000-0000-0000-0000-000000000004'
)
  AND r.business_date >= current_date - 7
ON CONFLICT (revenue_id, version) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. Chốt doanh thu tháng, hóa đơn và thanh toán
-- ---------------------------------------------------------------------------
WITH periods AS (
    SELECT (date_trunc('month', current_date) - (n || ' month')::interval)::date AS period_month
    FROM generate_series(1, 4) n
), totals AS (
    SELECT r.store_id, p.period_month,
        sum(r.gross_revenue)::numeric(18, 0) AS gross,
        sum(r.promotion_discount)::numeric(18, 0) AS discount,
        sum(r.net_revenue)::numeric(18, 0) AS net,
        round(sum(r.promotion_discount) * 0.45)::numeric(18, 0) AS brand_support
    FROM periods p
    JOIN app.revenues r ON r.business_date >= p.period_month
        AND r.business_date < p.period_month + interval '1 month'
        AND r.status = 'APPROVED'
    WHERE r.store_id IN (
        SELECT ('92000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid
        FROM generate_series(1, 6) n
    )
    GROUP BY r.store_id, p.period_month
)
INSERT INTO app.monthly_closes (
    id, store_id, period_month, monthly_gross_revenue,
    monthly_promotion_discount, monthly_net_revenue,
    brand_promotion_support, closed_by, closed_at
)
SELECT md5('monthly-close:' || store_id::text || ':' || period_month::text)::uuid,
    store_id, period_month, gross, discount, net, brand_support,
    '90000000-0000-0000-0000-000000000003',
    (period_month + interval '1 month 2 days 9 hours')::timestamptz
FROM totals
ON CONFLICT (store_id, period_month) DO UPDATE SET
    monthly_gross_revenue = EXCLUDED.monthly_gross_revenue,
    monthly_promotion_discount = EXCLUDED.monthly_promotion_discount,
    monthly_net_revenue = EXCLUDED.monthly_net_revenue,
    brand_promotion_support = EXCLUDED.brand_promotion_support,
    closed_by = EXCLUDED.closed_by, closed_at = EXCLUDED.closed_at;

WITH invoice_base AS (
    SELECT mc.*, s.code AS store_code, c.id AS contract_id,
        c.royalty_rate, c.system_fee, c.service_fee,
        ((date_part('year', age(date_trunc('month', current_date), mc.period_month)) * 12)
          + date_part('month', age(date_trunc('month', current_date), mc.period_month)))::integer AS months_ago,
        round(mc.monthly_net_revenue * c.royalty_rate / 100)::numeric(18, 0) AS royalty_fee
    FROM app.monthly_closes mc
    JOIN app.stores s ON s.id = mc.store_id
    JOIN app.contracts c ON c.store_id = mc.store_id AND c.status = 'ACTIVE'
    WHERE mc.period_month >= (date_trunc('month', current_date) - interval '3 months')::date
), calculated AS (
    SELECT b.*,
        (b.royalty_fee + b.system_fee + b.service_fee)::numeric(18, 0) AS fee_subtotal,
        greatest(b.royalty_fee + b.system_fee + b.service_fee
            - b.brand_promotion_support, 0)::numeric(18, 0) AS taxable_amount
    FROM invoice_base b
), finalized AS (
    SELECT c.*, round(c.taxable_amount * 0.10)::numeric(18, 0) AS vat_amount,
        (c.taxable_amount + round(c.taxable_amount * 0.10))::numeric(18, 0) AS invoice_total,
        CASE
            WHEN c.months_ago = 3 THEN 'PAID'
            WHEN c.months_ago = 2 AND right(c.store_code, 1)::integer % 2 = 0 THEN 'PAID'
            WHEN c.months_ago = 2 THEN 'PARTIALLY_PAID'
            WHEN c.months_ago = 1 AND right(c.store_code, 1)::integer % 2 = 0 THEN 'ISSUED'
            ELSE 'OVERDUE'
        END AS invoice_status
    FROM calculated c
)
INSERT INTO app.invoices (
    id, invoice_no, store_id, contract_id, monthly_close_id, period_month,
    royalty_rate, monthly_gross_revenue, royalty_fee, system_fee, service_fee,
    initial_fee_installment, positive_adjustments, brand_promotion_support,
    carried_credit, negative_adjustments, fee_subtotal, deductions,
    taxable_amount, vat_rate, vat_amount, invoice_total,
    paid_amount, outstanding_amount, status, issued_at, due_date,
    created_by, created_at, updated_at
)
SELECT
    md5('invoice:' || store_id::text || ':' || period_month::text)::uuid,
    'INV-' || to_char(period_month, 'YYYYMM') || '-' || store_code,
    store_id, contract_id, id, period_month,
    royalty_rate, monthly_gross_revenue, royalty_fee, system_fee, service_fee,
    0, 0, brand_promotion_support, 0, 0,
    fee_subtotal, brand_promotion_support, taxable_amount, 10, vat_amount, invoice_total,
    CASE WHEN invoice_status = 'PAID' THEN invoice_total
         WHEN invoice_status = 'PARTIALLY_PAID' THEN round(invoice_total * 0.55)
         ELSE 0 END,
    CASE WHEN invoice_status = 'PAID' THEN 0
         WHEN invoice_status = 'PARTIALLY_PAID' THEN invoice_total - round(invoice_total * 0.55)
         ELSE invoice_total END,
    invoice_status,
    (period_month + interval '1 month 3 days 9 hours')::timestamptz,
    (period_month + interval '1 month 15 days')::date,
    '90000000-0000-0000-0000-000000000003',
    (period_month + interval '1 month 2 days 9 hours')::timestamptz,
    (period_month + interval '1 month 3 days 9 hours')::timestamptz
FROM finalized
ON CONFLICT (id) DO UPDATE SET
    monthly_gross_revenue = EXCLUDED.monthly_gross_revenue,
    royalty_fee = EXCLUDED.royalty_fee, system_fee = EXCLUDED.system_fee,
    service_fee = EXCLUDED.service_fee,
    brand_promotion_support = EXCLUDED.brand_promotion_support,
    fee_subtotal = EXCLUDED.fee_subtotal, deductions = EXCLUDED.deductions,
    taxable_amount = EXCLUDED.taxable_amount, vat_amount = EXCLUDED.vat_amount,
    invoice_total = EXCLUDED.invoice_total, paid_amount = EXCLUDED.paid_amount,
    outstanding_amount = EXCLUDED.outstanding_amount, status = EXCLUDED.status,
    issued_at = EXCLUDED.issued_at, due_date = EXCLUDED.due_date,
    updated_at = EXCLUDED.updated_at;

INSERT INTO app.invoice_items (id, invoice_id, item_type, description, amount)
SELECT md5('invoice-item:' || i.id::text || ':' || item.item_type)::uuid,
    i.id, item.item_type, item.description,
    CASE item.item_type WHEN 'ROYALTY_FEE' THEN i.royalty_fee
         WHEN 'SYSTEM_FEE' THEN i.system_fee ELSE i.service_fee END
FROM app.invoices i
CROSS JOIN (VALUES
    ('ROYALTY_FEE', 'Phí nhượng quyền theo doanh thu tháng'),
    ('SYSTEM_FEE', 'Phí sử dụng hệ thống quản lý'),
    ('SERVICE_FEE', 'Phí hỗ trợ vận hành và marketing')
) AS item(item_type, description)
WHERE i.id IN (
    SELECT md5('invoice:' || mc.store_id::text || ':' || mc.period_month::text)::uuid
    FROM app.monthly_closes mc
    WHERE mc.period_month >= (date_trunc('month', current_date) - interval '3 months')::date
)
ON CONFLICT (id) DO UPDATE SET
    description = EXCLUDED.description, amount = EXCLUDED.amount;

INSERT INTO app.payments (
    id, payment_no, invoice_id, amount, payment_date,
    method, reference_no, status, recorded_by, created_at
)
SELECT md5('payment:' || i.id::text)::uuid,
    'PAY-' || to_char(i.period_month, 'YYYYMM') || '-' || s.code,
    i.id, i.paid_amount, LEAST(i.due_date, current_date - 1),
    'BANK_TRANSFER', 'VCB' || to_char(i.period_month, 'YYMM') || replace(s.code, '-', ''),
    'CONFIRMED', '90000000-0000-0000-0000-000000000003',
    LEAST(i.due_date, current_date - 1)::timestamptz + interval '10 hours'
FROM app.invoices i
JOIN app.stores s ON s.id = i.store_id
WHERE i.paid_amount > 0
  AND i.id IN (
      SELECT md5('invoice:' || mc.store_id::text || ':' || mc.period_month::text)::uuid
      FROM app.monthly_closes mc
      WHERE mc.period_month >= (date_trunc('month', current_date) - interval '3 months')::date
  )
ON CONFLICT (id) DO UPDATE SET
    amount = EXCLUDED.amount, payment_date = EXCLUDED.payment_date,
    method = EXCLUDED.method, reference_no = EXCLUDED.reference_no,
    status = EXCLUDED.status, reversed_by = NULL,
    reversed_at = NULL, reversal_reason = NULL;

-- ---------------------------------------------------------------------------
-- 7. Thông báo và nhật ký hoạt động
-- ---------------------------------------------------------------------------
INSERT INTO app.notifications (
    id, user_id, notification_type, title, message,
    entity_type, entity_id, dedupe_key, read_at, created_at
)
VALUES
    ('96000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002',
     'REVENUE_SUBMITTED', 'Doanh thu đã được tiếp nhận',
     'Báo cáo doanh thu ngày gần nhất đang chờ kế toán kiểm tra.',
     'REVENUE', md5('revenue:92000000-0000-0000-0000-000000000001:' || (current_date - 1)::text)::uuid,
     'SEED:REVENUE:OWNER-001', NULL, now() - interval '5 hours'),
    ('96000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000004',
     'REVENUE_ADJUSTMENT', 'Yêu cầu điều chỉnh doanh thu',
     'Kế toán yêu cầu bổ sung doanh thu từ đơn hàng giao qua ứng dụng.',
     'REVENUE', md5('revenue:92000000-0000-0000-0000-000000000002:' || (current_date - 1)::text)::uuid,
     'SEED:REVENUE:OWNER-002', NULL, now() - interval '2 hours'),
    ('96000000-0000-0000-0000-000000000003', '90000000-0000-0000-0000-000000000007',
     'INVOICE_OVERDUE', 'Hóa đơn phí nhượng quyền sắp quá hạn',
     'Vui lòng kiểm tra hóa đơn kỳ gần nhất và hoàn tất thanh toán.',
     'STORE', '92000000-0000-0000-0000-000000000005',
     'SEED:INVOICE:OWNER-005', NULL, now() - interval '1 day'),
    ('96000000-0000-0000-0000-000000000004', '90000000-0000-0000-0000-000000000003',
     'REVENUE_SUBMITTED', 'Có báo cáo doanh thu chờ duyệt',
     'Cửa hàng Hoàn Kiếm vừa gửi báo cáo doanh thu ngày gần nhất.',
     'STORE', '92000000-0000-0000-0000-000000000001',
     'SEED:ACCOUNTANT:PENDING-REVENUE', NULL, now() - interval '4 hours'),
    ('96000000-0000-0000-0000-000000000005', '90000000-0000-0000-0000-000000000001',
     'APPLICATION_SUBMITTED', 'Hồ sơ mới cần thẩm định',
     'Hồ sơ mở cửa hàng tại thành phố Vinh đang chờ tiếp nhận.',
     'FRANCHISE_APPLICATION', '91000000-0000-0000-0000-000000000009',
     'SEED:ADMIN:PENDING-APPLICATION', NULL, now() - interval '3 days'),
    ('96000000-0000-0000-0000-000000000006', '90000000-0000-0000-0000-000000000008',
     'PROMOTION_STARTED', 'Khuyến mãi mới đã bắt đầu',
     'Chương trình Cuối tuần Sài Gòn đã được áp dụng cho cửa hàng Thảo Điền.',
     'PROMOTION', '94000000-0000-0000-0000-000000000004',
     'SEED:PROMOTION:OWNER-006', now() - interval '2 days', now() - interval '7 days')
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title, message = EXCLUDED.message,
    entity_type = EXCLUDED.entity_type, entity_id = EXCLUDED.entity_id,
    read_at = EXCLUDED.read_at, created_at = EXCLUDED.created_at;

INSERT INTO app.audit_logs (actor_id, action, entity_type, entity_id, new_values, reason, created_at)
SELECT seeded.actor_id, seeded.action, seeded.entity_type, seeded.entity_id,
       seeded.new_values, seeded.reason, seeded.created_at
FROM (VALUES
    ('90000000-0000-0000-0000-000000000001'::uuid, 'CREATE_STORE', 'STORE',
     '92000000-0000-0000-0000-000000000007'::uuid,
     '{"code":"QN-HL-007","status":"INACTIVE"}'::jsonb,
     'Tạo cửa hàng từ hồ sơ nhượng quyền đã được duyệt', now() - interval '60 days'),
    ('90000000-0000-0000-0000-000000000001'::uuid, 'ACTIVATE_CONTRACT', 'CONTRACT',
     '93000000-0000-0000-0000-000000000006'::uuid,
     '{"status":"ACTIVE"}'::jsonb,
     'Đã nhận đủ phí ban đầu và tiền ký quỹ', now() - interval '330 days'),
    ('90000000-0000-0000-0000-000000000003'::uuid, 'APPROVE_REVENUE', 'REVENUE',
     md5('revenue:92000000-0000-0000-0000-000000000001:' || (current_date - 2)::text)::uuid,
     '{"status":"APPROVED"}'::jsonb,
     'Doanh thu khớp dữ liệu chốt ca', now() - interval '1 day'),
    ('90000000-0000-0000-0000-000000000003'::uuid, 'ISSUE_INVOICE', 'INVOICE',
     md5('invoice:92000000-0000-0000-0000-000000000001:' ||
         (date_trunc('month', current_date) - interval '1 month')::date::text)::uuid,
     '{"status":"OVERDUE"}'::jsonb,
     'Phát hành hóa đơn phí nhượng quyền kỳ gần nhất', now() - interval '20 days'),
    ('90000000-0000-0000-0000-000000000003'::uuid, 'RECORD_PAYMENT', 'PAYMENT',
     md5('payment:' || md5('invoice:92000000-0000-0000-0000-000000000002:' ||
         (date_trunc('month', current_date) - interval '2 months')::date::text)::uuid::text)::uuid,
     '{"status":"CONFIRMED","method":"BANK_TRANSFER"}'::jsonb,
     'Đã đối chiếu giao dịch ngân hàng', now() - interval '35 days')
) AS seeded(actor_id, action, entity_type, entity_id, new_values, reason, created_at)
WHERE NOT EXISTS (
    SELECT 1 FROM app.audit_logs a
    WHERE a.action = seeded.action AND a.entity_id = seeded.entity_id
);

SELECT format(
    'Seed hoàn tất: %s người dùng, %s hồ sơ, %s cửa hàng, %s hợp đồng, %s doanh thu, %s hóa đơn, %s thanh toán.',
    (SELECT count(*) FROM app.users WHERE deleted_at IS NULL),
    (SELECT count(*) FROM app.franchise_applications WHERE deleted_at IS NULL),
    (SELECT count(*) FROM app.stores WHERE deleted_at IS NULL),
    (SELECT count(*) FROM app.contracts),
    (SELECT count(*) FROM app.revenues),
    (SELECT count(*) FROM app.invoices),
    (SELECT count(*) FROM app.payments)
);

COMMIT;
