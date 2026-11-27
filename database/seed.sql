-- =============================================================================
-- Dữ liệu mẫu thực tế cho chuỗi "Mộc Miên Coffee".
-- * Mọi ID do database tự sinh (DEFAULT gen_random_uuid()); các bản ghi liên kết
--   với nhau qua khóa tự nhiên: email, mã cửa hàng, số hợp đồng, số hóa đơn.
-- * Đi đúng luồng nghiệp vụ: hồ sơ được duyệt -> hợp đồng ký + thu phí ->
--   kích hoạt -> cửa hàng mở; doanh thu hằng ngày -> kế toán duyệt -> hóa đơn
--   tháng (phí bản quyền trên doanh thu gộp, thương hiệu chịu 100% khuyến mãi,
--   VAT 10%) -> thanh toán.
-- * Mọi ngày tháng tính tương đối theo current_date nên dữ liệu luôn "mới".
-- * Chỉ chạy khi database chưa có người dùng (xem run-seed.sh).
-- Tất cả tài khoản dùng mật khẩu: Admin@123
-- =============================================================================
BEGIN;
SELECT setseed(0.2026);

-- ---------------------------------------------------------------------------
-- 1. Người dùng
-- ---------------------------------------------------------------------------
INSERT INTO app.users (email, password_hash, full_name, phone, roles, created_at, last_login_at)
SELECT v.email,
       '$argon2id$v=19$m=65536,t=3,p=4$GCS9gjKoIzSDnIJaSdgHWw$DD11WnCEi0PTaX+LZcWPizuh6dir7z7kbuUrO0NEtJo',
       v.full_name, v.phone, v.roles::varchar(30)[],
       now() - make_interval(days => v.joined_days_ago),
       CASE WHEN v.roles <> '{}' THEN now() - make_interval(hours => v.joined_days_ago % 48) END
FROM (VALUES
    ('admin@franchise.local',            'Nguyễn Hoàng Nam',   '0901234567', '{ADMIN}',        900),
    ('accountant@franchise.local',       'Trần Thu Hà',        '0903456781', '{ACCOUNTANT}',   880),
    ('ketoan.minh@franchise.local',      'Phạm Đức Minh',      '0912678345', '{ACCOUNTANT}',   400),
    ('owner@franchise.local',            'Lê Minh Anh',        '0912345678', '{STORE_OWNER}',  600),
    ('pham.quang.huy@franchise.local',   'Phạm Quang Huy',     '0903456789', '{STORE_OWNER}',  560),
    ('vu.ngoc.lan@franchise.local',      'Vũ Ngọc Lan',        '0934567890', '{STORE_OWNER}',  490),
    ('ngo.duc.thang@franchise.local',    'Ngô Đức Thắng',      '0985123456', '{STORE_OWNER}',  450),
    ('do.thanh.tung@franchise.local',    'Đỗ Thanh Tùng',      '0945678901', '{STORE_OWNER}',  470),
    ('bui.thanh.huong@franchise.local',  'Bùi Thanh Hương',    '0978234561', '{STORE_OWNER}',  300),
    ('nguyen.thao.vy@franchise.local',   'Nguyễn Thảo Vy',     '0909876543', '{STORE_OWNER}',  540),
    ('hoang.gia.bao@franchise.local',    'Hoàng Gia Bảo',      '0918765432', '{STORE_OWNER}',  420),
    ('tran.minh.chau@franchise.local',   'Trần Minh Châu',     '0938112233', '{STORE_OWNER}',  350),
    ('le.hoang.phuc@franchise.local',    'Lê Hoàng Phúc',      '0967334455', '{STORE_OWNER}',  270),
    ('dang.thu.trang@franchise.local',   'Đặng Thu Trang',     '0939556677', '{STORE_OWNER}',  380),
    ('vo.quoc.khanh@franchise.local',    'Võ Quốc Khánh',      '0905667788', '{STORE_OWNER}',  240),
    ('truong.my.linh@franchise.local',   'Trương Mỹ Linh',     '0918990011', '{STORE_OWNER}',  180),
    ('bui.khanh.linh@franchise.local',   'Bùi Khánh Linh',     '0888901234', '{}',              95),
    ('dang.tuan.kiet@franchise.local',   'Đặng Tuấn Kiệt',     '0977012345', '{}',              12),
    ('mai.phuong.thao@franchise.local',  'Mai Phương Thảo',    '0966123456', '{}',              25),
    ('nguyen.van.son@franchise.local',   'Nguyễn Văn Sơn',     '0913223344', '{}',               4),
    ('truong.duc.long@franchise.local',  'Trương Đức Long',    '0911234567', '{}',              70),
    ('ngo.hai.yen@franchise.local',      'Ngô Hải Yến',        '0923344556', '{}',              50)
) AS v(email, full_name, phone, roles, joined_days_ago);

-- ---------------------------------------------------------------------------
-- 2. Danh mục cửa hàng nhượng quyền (bảng tạm, chỉ dùng trong seed)
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE seed_store (
    no int, code text, name text, address text, phone text, store_email text,
    owner_email text, opened_days_ago int, area numeric, budget numeric,
    royalty numeric, initial_fee numeric, deposit numeric, system_fee numeric,
    service_fee numeric, base_daily numeric, status text, suspended_days_ago int
) ON COMMIT DROP;
INSERT INTO seed_store VALUES
 ( 1,'CH0001','Mộc Miên Coffee Hoàn Kiếm','38 Hàng Bông, phường Hàng Bông, quận Hoàn Kiếm, Hà Nội','02439361268','hoankiem@mocmien.vn','owner@franchise.local',520,118,1850000000,5.0,180000000,50000000,1500000,2500000,16500000,'ACTIVE',NULL),
 ( 2,'CH0002','Mộc Miên Coffee Cầu Giấy','126 Trần Thái Tông, phường Dịch Vọng Hậu, quận Cầu Giấy, Hà Nội','02437681226','caugiay@mocmien.vn','pham.quang.huy@franchise.local',470,95,1600000000,5.0,180000000,50000000,1500000,2500000,14200000,'ACTIVE',NULL),
 ( 3,'CH0003','Mộc Miên Coffee Bạch Mai','215 Bạch Mai, phường Cầu Dền, quận Hai Bà Trưng, Hà Nội','02436281125','bachmai@mocmien.vn','vu.ngoc.lan@franchise.local',400,88,1500000000,5.5,165000000,45000000,1500000,2200000,12800000,'ACTIVE',NULL),
 ( 4,'CH0004','Mộc Miên Coffee Thanh Xuân','72A Nguyễn Trãi, phường Thượng Đình, quận Thanh Xuân, Hà Nội','02435578072','thanhxuan@mocmien.vn','owner@franchise.local',300,105,1700000000,5.0,180000000,50000000,1500000,2500000,15100000,'ACTIVE',NULL),
 ( 5,'CH0005','Mộc Miên Coffee Lê Chân','156 Tô Hiệu, phường Trại Cau, quận Lê Chân, Hải Phòng','02253856156','lechan@mocmien.vn','ngo.duc.thang@franchise.local',360,90,1300000000,5.0,160000000,40000000,1400000,2000000,11300000,'ACTIVE',NULL),
 ( 6,'CH0006','Mộc Miên Coffee Hải Châu','84 Nguyễn Văn Linh, phường Nam Dương, quận Hải Châu, Đà Nẵng','02363561284','haichau@mocmien.vn','do.thanh.tung@franchise.local',380,110,1650000000,5.0,175000000,50000000,1400000,2300000,13600000,'ACTIVE',NULL),
 ( 7,'CH0007','Mộc Miên Coffee Sơn Trà','25 Võ Nguyên Giáp, phường Phước Mỹ, quận Sơn Trà, Đà Nẵng','02363942025','sontra@mocmien.vn','bui.thanh.huong@franchise.local',215,130,2000000000,5.5,190000000,55000000,1500000,2500000,15800000,'ACTIVE',NULL),
 ( 8,'CH0008','Mộc Miên Coffee Nguyễn Huệ','112 Nguyễn Huệ, phường Bến Nghé, Quận 1, TP. Hồ Chí Minh','02838221112','nguyenhue@mocmien.vn','nguyen.thao.vy@franchise.local',450,140,2400000000,6.0,220000000,70000000,1800000,3000000,21500000,'ACTIVE',NULL),
 ( 9,'CH0009','Mộc Miên Coffee Thảo Điền','46 Xuân Thủy, phường Thảo Điền, TP. Thủ Đức, TP. Hồ Chí Minh','02837441246','thaodien@mocmien.vn','hoang.gia.bao@franchise.local',330,125,2100000000,5.5,200000000,60000000,1700000,2800000,18700000,'ACTIVE',NULL),
 (10,'CH0010','Mộc Miên Coffee Võ Văn Tần','203 Võ Văn Tần, phường Võ Thị Sáu, Quận 3, TP. Hồ Chí Minh','02839307203','vovantan@mocmien.vn','tran.minh.chau@franchise.local',265,98,1750000000,5.5,190000000,55000000,1700000,2600000,16900000,'ACTIVE',NULL),
 (11,'CH0011','Mộc Miên Coffee Phan Xích Long','88 Phan Xích Long, phường 2, quận Phú Nhuận, TP. Hồ Chí Minh','02835173088','phanxichlong@mocmien.vn','le.hoang.phuc@franchise.local',185,92,1550000000,5.0,180000000,50000000,1600000,2500000,14500000,'ACTIVE',NULL),
 (12,'CH0012','Mộc Miên Coffee Ninh Kiều','72 Hai Bà Trưng, phường Tân An, quận Ninh Kiều, Cần Thơ','02923811272','ninhkieu@mocmien.vn','dang.thu.trang@franchise.local',290,100,1350000000,5.0,160000000,40000000,1400000,2000000,10400000,'SUSPENDED',12),
 (13,'CH0013','Mộc Miên Coffee Nha Trang','52 Trần Phú, phường Lộc Thọ, TP. Nha Trang, Khánh Hòa','02583522052','nhatrang@mocmien.vn','vo.quoc.khanh@franchise.local',150,115,1800000000,5.5,185000000,55000000,1500000,2400000,13900000,'ACTIVE',NULL),
 (14,'CH0014','Mộc Miên Coffee Đà Lạt','18 Trần Quốc Toản, phường 1, TP. Đà Lạt, Lâm Đồng','02633821018','dalat@mocmien.vn','truong.my.linh@franchise.local',95,85,1400000000,5.0,170000000,45000000,1400000,2200000,11800000,'ACTIVE',NULL),
 (15,'CH0015','Mộc Miên Coffee Long Biên','9 Nguyễn Văn Cừ, phường Ngọc Lâm, quận Long Biên, Hà Nội','02438271009','longbien@mocmien.vn','pham.quang.huy@franchise.local',45,100,1600000000,5.0,180000000,50000000,1500000,2500000,12900000,'ACTIVE',NULL);

-- ---------------------------------------------------------------------------
-- 3. Hồ sơ nhượng quyền của các cửa hàng đã mở (đã duyệt, đã chuyển đổi)
-- ---------------------------------------------------------------------------
INSERT INTO app.franchise_applications (
    applicant_id, applicant_name, email, phone, proposed_store_name,
    proposed_address, proposed_area, investment_budget, note, status,
    review_started_by, review_started_at, review_note, reviewed_by, reviewed_at,
    converted_at, created_at, updated_at
)
SELECT u.id, u.full_name, u.email, u.phone, s.name, s.address, s.area, s.budget,
       'Mặt bằng thuê dài hạn, đã khảo sát lượng khách văn phòng và sinh viên khu vực.',
       'APPROVED', a.id, now() - make_interval(days => s.opened_days_ago + 30),
       'Hồ sơ đầy đủ, địa điểm phù hợp tiêu chuẩn thương hiệu.',
       a.id, now() - make_interval(days => s.opened_days_ago + 21),
       now() - make_interval(days => s.opened_days_ago),
       now() - make_interval(days => s.opened_days_ago + 45),
       now() - make_interval(days => s.opened_days_ago)
FROM seed_store s
JOIN app.users u ON u.email = s.owner_email
CROSS JOIN (SELECT id FROM app.users WHERE email = 'admin@franchise.local') a;

-- Hồ sơ đang ở các trạng thái khác (mỗi người một hồ sơ)
INSERT INTO app.franchise_applications (
    applicant_id, applicant_name, email, phone, proposed_store_name,
    proposed_address, proposed_area, investment_budget, note, status,
    review_started_by, review_started_at, review_note, reviewed_by, reviewed_at,
    withdrawn_by, withdrawn_at, withdrawal_reason, created_at, updated_at
)
SELECT u.id, u.full_name, u.email, u.phone, v.store_name, v.address, v.area, v.budget, v.note, v.status,
       CASE WHEN v.status IN ('UNDER_REVIEW','APPROVED','REJECTED') THEN a.id END,
       CASE WHEN v.status IN ('UNDER_REVIEW','APPROVED','REJECTED') THEN now() - make_interval(days => v.days_ago - 3) END,
       v.review_note,
       CASE WHEN v.status IN ('APPROVED','REJECTED') THEN a.id END,
       CASE WHEN v.status IN ('APPROVED','REJECTED') THEN now() - make_interval(days => v.days_ago - 8) END,
       CASE WHEN v.status = 'WITHDRAWN' THEN u.id END,
       CASE WHEN v.status = 'WITHDRAWN' THEN now() - make_interval(days => v.days_ago - 5) END,
       CASE WHEN v.status = 'WITHDRAWN' THEN 'Gia đình thay đổi kế hoạch đầu tư, xin rút hồ sơ.' END,
       now() - make_interval(days => v.days_ago), now() - make_interval(days => greatest(v.days_ago - 8, 0))
FROM (VALUES
 ('bui.khanh.linh@franchise.local','Mộc Miên Coffee Hạ Long','128 đường Hạ Long, phường Bãi Cháy, TP. Hạ Long, Quảng Ninh',138,2100000000,'Cửa hàng hướng biển, dự kiến khai trương đầu quý tới.','APPROVED','Đã duyệt, chờ ký hợp đồng và thanh toán phí ban đầu.',40),
 ('mai.phuong.thao@franchise.local','Mộc Miên Coffee Vinh','35 Quang Trung, phường Quang Trung, TP. Vinh, Nghệ An',96,1350000000,'Gần trường đại học Vinh, lượng sinh viên đông.','UNDER_REVIEW','Đang thẩm định mặt bằng và năng lực tài chính.',18),
 ('dang.tuan.kiet@franchise.local','Mộc Miên Coffee Biên Hòa','210 Phạm Văn Thuận, phường Tân Tiến, TP. Biên Hòa, Đồng Nai',110,1600000000,'Khu dân cư mới, chưa có thương hiệu cà phê chuỗi.','PENDING',NULL,10),
 ('nguyen.van.son@franchise.local','Mộc Miên Coffee Huế','14 Lê Lợi, phường Vĩnh Ninh, TP. Huế, Thừa Thiên Huế',90,1250000000,'Mặt tiền đường Lê Lợi, gần sông Hương.','PENDING',NULL,3),
 ('truong.duc.long@franchise.local','Mộc Miên Coffee Mỹ Đình','8 Lê Đức Thọ, phường Mỹ Đình 2, quận Nam Từ Liêm, Hà Nội',60,800000000,'Mặt bằng nhỏ trong ngõ.','REJECTED','Diện tích dưới 80 m² và ngân sách chưa đạt mức tối thiểu của thương hiệu.',65),
 ('ngo.hai.yen@franchise.local','Mộc Miên Coffee Vũng Tàu','45 Thùy Vân, phường Thắng Tam, TP. Vũng Tàu, Bà Rịa - Vũng Tàu',120,1900000000,'Mặt biển Bãi Sau.','WITHDRAWN',NULL,45)
) AS v(email, store_name, address, area, budget, note, status, review_note, days_ago)
JOIN app.users u ON u.email = v.email
CROSS JOIN (SELECT id FROM app.users WHERE email = 'admin@franchise.local') a;

-- ---------------------------------------------------------------------------
-- 4. Cửa hàng (được mở khi hợp đồng kích hoạt) và hợp đồng
-- ---------------------------------------------------------------------------
INSERT INTO app.stores (code, name, owner_id, application_id, address, phone, email,
                        status, activated_at, created_at, updated_at)
SELECT s.code, s.name, u.id, fa.id, s.address, s.phone, s.store_email,
       s.status, now() - make_interval(days => s.opened_days_ago),
       now() - make_interval(days => s.opened_days_ago),
       now() - make_interval(days => coalesce(s.suspended_days_ago, s.opened_days_ago))
FROM seed_store s
JOIN app.users u ON u.email = s.owner_email
JOIN app.franchise_applications fa ON fa.applicant_id = u.id AND fa.proposed_store_name = s.name;

INSERT INTO app.contracts (
    contract_no, application_id, store_id, store_code, store_name, store_address,
    store_phone, store_email, signed_date, effective_from, effective_to,
    royalty_rate, initial_franchise_fee, deposit_amount, system_fee, service_fee,
    status, created_at, updated_at
)
SELECT 'HĐNQ-' || to_char(st.activated_at, 'YYYY') || '-' || lpad(s.no::text, 3, '0'),
       st.application_id, st.id, s.code, s.name, s.address, s.phone, s.store_email,
       (st.activated_at - interval '3 days')::date, st.activated_at::date,
       (st.activated_at + interval '5 years')::date,
       s.royalty, s.initial_fee, s.deposit, s.system_fee, s.service_fee, 'ACTIVE',
       st.activated_at - interval '12 days', st.activated_at
FROM seed_store s JOIN app.stores st ON st.code = s.code;

-- Hồ sơ Hạ Long: hợp đồng đã ký, cửa hàng đã được tạo tự động và đang chuẩn bị
-- khai trương (chưa hoạt động); chờ thu tối thiểu 20% phí ban đầu để kích hoạt.
UPDATE app.users SET roles = '{STORE_OWNER}' WHERE email = 'bui.khanh.linh@franchise.local';
UPDATE app.franchise_applications fa SET converted_at = now() - interval '6 days'
FROM app.users u WHERE u.id = fa.applicant_id AND u.email = 'bui.khanh.linh@franchise.local';
INSERT INTO app.stores (code, name, owner_id, application_id, address, phone, email, status, created_at, updated_at)
SELECT 'CH0016', fa.proposed_store_name, fa.applicant_id, fa.id, fa.proposed_address,
       fa.phone, fa.email, 'INACTIVE', now() - interval '6 days', now() - interval '6 days'
FROM app.franchise_applications fa JOIN app.users u ON u.id = fa.applicant_id
WHERE u.email = 'bui.khanh.linh@franchise.local';
INSERT INTO app.contracts (
    contract_no, application_id, store_id, store_code, store_name, store_address, store_phone,
    store_email, signed_date, effective_from, effective_to, royalty_rate,
    initial_franchise_fee, deposit_amount, system_fee, service_fee, status, created_at
)
SELECT 'HĐNQ-' || to_char(current_date, 'YYYY') || '-016', st.application_id, st.id, st.code,
       st.name, st.address, st.phone, st.email,
       current_date - 2, current_date + 14, (current_date + 14 + interval '5 years')::date,
       5.0, 185000000, 55000000, 1500000, 2500000, 'DRAFT', now() - interval '6 days'
FROM app.stores st WHERE st.code = 'CH0016';
SELECT setval('app.store_code_seq', 16);

-- Khoản thu theo hợp đồng: phí ban đầu (30% khi ký, 70% trước khai trương) và tiền cọc
INSERT INTO app.contract_financial_transactions (
    contract_id, transaction_type, amount, transaction_date, reference_no, note, recorded_by, created_at
)
SELECT c.id, t.kind, round(c.initial_franchise_fee * t.share), c.signed_date + t.offset_days,
       'VCB' || to_char(c.signed_date + t.offset_days, 'YYMMDD') || replace(c.store_code, '-', '') || t.offset_days,
       t.note, a.id, (c.signed_date + t.offset_days)::timestamptz + interval '10 hours'
FROM app.contracts c
CROSS JOIN (VALUES
    ('INITIAL_FEE_PAYMENT', 0.30, 0, 'Đợt 1 phí nhượng quyền ban đầu (30%)'),
    ('INITIAL_FEE_PAYMENT', 0.70, 2, 'Đợt 2 phí nhượng quyền ban đầu (70%)')
) AS t(kind, share, offset_days, note)
CROSS JOIN (SELECT id FROM app.users WHERE email = 'admin@franchise.local') a
WHERE c.status = 'ACTIVE';
INSERT INTO app.contract_financial_transactions (
    contract_id, transaction_type, amount, transaction_date, reference_no, note, recorded_by, created_at
)
SELECT c.id, 'DEPOSIT_PAYMENT', c.deposit_amount, c.signed_date,
       'VCB' || to_char(c.signed_date, 'YYMMDD') || 'COC' || replace(c.store_code, '-', ''),
       'Tiền ký quỹ bảo đảm thực hiện hợp đồng', a.id, c.signed_date::timestamptz + interval '11 hours'
FROM app.contracts c
CROSS JOIN (SELECT id FROM app.users WHERE email = 'admin@franchise.local') a
WHERE c.status = 'ACTIVE';

-- ---------------------------------------------------------------------------
-- 5. Khuyến mãi (thương hiệu chịu 100% chi phí)
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE seed_promo (
    name text, description text, discount_type text, discount_value numeric,
    start_offset int, end_offset int, scope text, status text,
    discount_share numeric, store_code text
) ON COMMIT DROP;
INSERT INTO seed_promo VALUES
 ('Chào hè sảng khoái','Giảm 10% toàn bộ đồ uống đá xay và trà trái cây.','PERCENTAGE',10,-170,-140,'ALL_STORES','EXPIRED',0.045,NULL),
 ('Mùa tựu trường','Giảm 15% cho học sinh, sinh viên khi xuất trình thẻ.','PERCENTAGE',15,-95,-81,'ALL_STORES','EXPIRED',0.035,NULL),
 ('Khai trương Long Biên','Giảm 20% mọi hóa đơn trong hai tuần khai trương.','PERCENTAGE',20,-45,-31,'SELECTED_STORES','EXPIRED',0.120,'CH0015'),
 ('Thu vàng ưu đãi','Mua 2 ly cà phê sữa đá tặng 1 bánh croissant.','FIXED_AMOUNT',25000,-55,-38,'ALL_STORES','EXPIRED',0.030,NULL),
 ('Đồng giá mùa mưa','Đồng giá 29.000 đồng cho trà nóng, đã hủy do thay đổi thực đơn.','FIXED_AMOUNT',29000,-30,-10,'ALL_STORES','CANCELLED',0,NULL),
 ('Tuần lễ khách hàng thân thiết','Giảm 20.000 đồng cho hóa đơn từ 150.000 đồng với thành viên Mộc Miên Rewards.','FIXED_AMOUNT',20000,-6,8,'ALL_STORES','ACTIVE',0.055,NULL),
 ('Cuối năm rộn ràng','Giảm 12% combo bánh và đồ uống dịp cuối năm.','PERCENTAGE',12,10,40,'ALL_STORES','DRAFT',0,NULL);

INSERT INTO app.promotions (name, description, discount_type, discount_value, start_date,
                            end_date, scope, status, created_by, created_at, updated_at)
SELECT p.name, p.description, p.discount_type, p.discount_value,
       current_date + p.start_offset, current_date + p.end_offset, p.scope, p.status, a.id,
       now() + make_interval(days => p.start_offset - 10), now() + make_interval(days => least(p.end_offset, 0))
FROM seed_promo p
CROSS JOIN (SELECT id FROM app.users WHERE email = 'admin@franchise.local') a;

INSERT INTO app.promotion_stores (promotion_id, store_id)
SELECT pr.id, st.id
FROM seed_promo p
JOIN app.promotions pr ON pr.name = p.name
JOIN app.stores st ON st.code = p.store_code
WHERE p.scope = 'SELECTED_STORES';

-- ---------------------------------------------------------------------------
-- 6. Doanh thu hằng ngày: tối đa 210 ngày gần nhất, theo mùa và thứ trong tuần
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE seed_revenue ON COMMIT DROP AS
SELECT st.id AS store_id, st.code, st.owner_id, d::date AS business_date,
       (current_date - d::date) AS days_ago,
       round(s.base_daily
           * CASE extract(isodow FROM d) WHEN 1 THEN 0.90 WHEN 2 THEN 0.92 WHEN 3 THEN 0.95
                 WHEN 4 THEN 1.00 WHEN 5 THEN 1.12 WHEN 6 THEN 1.32 ELSE 1.27 END
           * CASE WHEN extract(month FROM d) IN (11, 12) THEN 1.08
                  WHEN extract(month FROM d) IN (6, 7, 8) AND s.code IN ('CH0013', 'CH0007', 'CH0014') THEN 1.18
                  WHEN extract(month FROM d) IN (6, 7, 8) THEN 1.04 ELSE 1.00 END
           * CASE WHEN d::date < st.activated_at::date + 30 THEN 1.15 ELSE 1.00 END
           * (0.90 + random() * 0.20) / 1000) * 1000 AS gross
FROM seed_store s
JOIN app.stores st ON st.code = s.code
CROSS JOIN LATERAL generate_series(
    greatest(st.activated_at::date, current_date - 210),
    current_date - 1 - coalesce(s.suspended_days_ago, 0), interval '1 day') AS d
-- Nha Trang chưa nộp doanh thu hôm qua (minh họa cảnh báo chậm báo cáo)
WHERE NOT (s.code = 'CH0013' AND d::date = current_date - 1);

INSERT INTO app.revenues (
    store_id, business_date, gross_revenue, promotion_discount, status, reported_by,
    reported_at, reviewed_by, reviewed_at, review_note, adjustment_requested_by,
    adjustment_requested_at, adjustment_reason, version, note, created_at, updated_at
)
SELECT r.store_id, r.business_date, r.gross,
       coalesce(round(r.gross * pm.discount_share / 1000) * 1000, 0),
       x.status, r.owner_id,
       CASE WHEN x.status <> 'DRAFT' THEN r.business_date + interval '1 day 21 hours' END,
       CASE WHEN x.status IN ('APPROVED', 'REJECTED', 'ADJUSTMENT_REQUESTED') THEN acc.id END,
       CASE WHEN x.status IN ('APPROVED', 'REJECTED', 'ADJUSTMENT_REQUESTED') THEN r.business_date + interval '2 days 9 hours 30 minutes' END,
       CASE WHEN x.status = 'REJECTED' THEN 'Doanh thu chênh lệch so với báo cáo chốt ca trên POS, vui lòng kiểm tra lại ca tối.' END,
       CASE WHEN x.status = 'ADJUSTMENT_REQUESTED' THEN acc.id END,
       CASE WHEN x.status = 'ADJUSTMENT_REQUESTED' THEN r.business_date + interval '3 days 14 hours' END,
       CASE WHEN x.status = 'ADJUSTMENT_REQUESTED' THEN 'Thiếu doanh thu đơn giao hàng qua ứng dụng, cần bổ sung.' END,
       CASE WHEN r.code = 'CH0005' AND r.days_ago = 20 THEN 2 ELSE 1 END,
       CASE WHEN r.code = 'CH0005' AND r.days_ago = 20 THEN 'Đã điều chỉnh theo yêu cầu kế toán (bổ sung đơn GrabFood).' END,
       r.business_date + interval '1 day 21 hours', r.business_date + interval '2 days 9 hours 30 minutes'
FROM seed_revenue r
CROSS JOIN LATERAL (
    SELECT CASE
        WHEN r.code = 'CH0009' AND r.days_ago = 4 THEN 'REJECTED'
        WHEN r.code = 'CH0003' AND r.days_ago = 6 THEN 'ADJUSTMENT_REQUESTED'
        WHEN r.days_ago >= 3 THEN 'APPROVED'
        WHEN r.days_ago = 2 AND r.code IN ('CH0001', 'CH0002', 'CH0008') THEN 'APPROVED'
        WHEN r.days_ago = 2 THEN 'SUBMITTED'
        WHEN right(r.code, 1)::int % 2 = 0 THEN 'SUBMITTED'
        ELSE 'DRAFT' END AS status
) x
LEFT JOIN LATERAL (
    SELECT p.discount_share, p.name
    FROM seed_promo p
    WHERE p.status IN ('ACTIVE', 'EXPIRED') AND p.discount_share > 0
      AND r.business_date BETWEEN current_date + p.start_offset AND current_date + p.end_offset
      AND (p.scope = 'ALL_STORES' OR p.store_code = r.code)
    ORDER BY p.discount_share DESC LIMIT 1
) pm ON true
CROSS JOIN LATERAL (
    SELECT id FROM app.users
    WHERE email = CASE WHEN extract(day FROM r.business_date)::int % 3 = 0
                       THEN 'ketoan.minh@franchise.local' ELSE 'accountant@franchise.local' END
) acc;

INSERT INTO app.revenue_promotion_details (revenue_id, promotion_id, discount_amount, promotion_name_snapshot, created_at)
SELECT rv.id, pr.id, rv.promotion_discount, pr.name, rv.created_at
FROM app.revenues rv
JOIN app.stores st ON st.id = rv.store_id
JOIN LATERAL (
    SELECT p.name FROM seed_promo p
    WHERE p.status IN ('ACTIVE', 'EXPIRED') AND p.discount_share > 0
      AND rv.business_date BETWEEN current_date + p.start_offset AND current_date + p.end_offset
      AND (p.scope = 'ALL_STORES' OR p.store_code = st.code)
    ORDER BY p.discount_share DESC LIMIT 1
) pm ON true
JOIN app.promotions pr ON pr.name = pm.name
WHERE rv.promotion_discount > 0;

-- ---------------------------------------------------------------------------
-- 7. Hóa đơn phí nhượng quyền theo tháng (6 tháng gần nhất, tính đúng công thức)
-- ---------------------------------------------------------------------------
WITH months AS (
    SELECT (date_trunc('month', current_date) - make_interval(months => k))::date AS period_month, k
    FROM generate_series(1, 6) k
), totals AS (
    SELECT st.id AS store_id, st.code, c.id AS contract_id, c.royalty_rate, c.system_fee,
           c.service_fee, m.period_month, m.k,
           sum(rv.gross_revenue) AS gross, sum(rv.promotion_discount) AS discount,
           sum(rv.net_revenue) AS net
    FROM months m
    JOIN app.revenues rv ON rv.business_date >= m.period_month
        AND rv.business_date < m.period_month + interval '1 month' AND rv.status = 'APPROVED'
    JOIN app.stores st ON st.id = rv.store_id
    JOIN app.contracts c ON c.store_id = st.id AND c.status = 'ACTIVE'
    GROUP BY st.id, st.code, c.id, c.royalty_rate, c.system_fee, c.service_fee, m.period_month, m.k
), calc AS (
    SELECT t.*, round(t.gross * t.royalty_rate / 100) AS royalty,
           round(t.gross * t.royalty_rate / 100) + t.system_fee + t.service_fee AS subtotal
    FROM totals t
), fin AS (
    SELECT c.*, greatest(c.subtotal - c.discount, 0) AS taxable,
           round(greatest(c.subtotal - c.discount, 0) * 0.10) AS vat,
           (c.period_month + interval '1 month 3 days 9 hours') AS issued_at,
           CASE
               WHEN c.k >= 3 THEN 'PAID'
               WHEN c.k = 2 AND c.code IN ('CH0005', 'CH0012') THEN 'PARTIAL'
               WHEN c.k = 2 THEN 'PAID'
               WHEN c.code IN ('CH0003', 'CH0010') THEN 'PARTIAL'
               WHEN c.code IN ('CH0006', 'CH0012', 'CH0013') THEN 'UNPAID'
               ELSE 'PAID' END AS pay_state
    FROM calc c
)
INSERT INTO app.invoices (
    invoice_no, store_id, contract_id, period_month, royalty_rate, monthly_gross_revenue,
    monthly_promotion_discount, monthly_net_revenue, royalty_fee, system_fee, service_fee,
    brand_promotion_support, fee_subtotal, deductions, taxable_amount, vat_rate, vat_amount,
    invoice_total, paid_amount, outstanding_amount, status, issued_at, due_date,
    created_by, created_at, updated_at
)
SELECT 'PNQ-' || to_char(f.period_month, 'YYYYMM') || '-' || f.code, f.store_id, f.contract_id,
       f.period_month, f.royalty_rate, f.gross, f.discount, f.net, f.royalty, f.system_fee,
       f.service_fee, f.discount, f.subtotal, f.discount, f.taxable, 10, f.vat,
       f.taxable + f.vat,
       CASE f.pay_state WHEN 'PAID' THEN f.taxable + f.vat WHEN 'PARTIAL' THEN round((f.taxable + f.vat) * 0.5) ELSE 0 END,
       CASE f.pay_state WHEN 'PAID' THEN 0 WHEN 'PARTIAL' THEN (f.taxable + f.vat) - round((f.taxable + f.vat) * 0.5) ELSE f.taxable + f.vat END,
       CASE WHEN f.pay_state = 'PAID' THEN 'PAID'
            WHEN (f.issued_at + interval '7 days')::date < current_date THEN 'OVERDUE'
            WHEN f.pay_state = 'PARTIAL' THEN 'PARTIALLY_PAID' ELSE 'ISSUED' END,
       f.issued_at, (f.issued_at + interval '7 days')::date,
       acc.id, f.issued_at - interval '1 day', f.issued_at
FROM fin f
CROSS JOIN (SELECT id FROM app.users WHERE email = 'accountant@franchise.local') acc;

-- Thanh toán: trả đủ (một số trả 2 đợt 60/40), trả một phần 50%
INSERT INTO app.payments (payment_no, invoice_id, amount, payment_date, method, reference_no,
                          status, recorded_by, created_at)
SELECT 'TT-' || to_char(i.period_month, 'YYYYMM') || '-' || st.code || '-' || p.seq,
       i.id, p.amount, p.pay_date,
       CASE WHEN st.code = 'CH0014' THEN 'CASH' ELSE 'BANK_TRANSFER' END,
       CASE WHEN st.code = 'CH0014' THEN 'PT' || to_char(p.pay_date, 'YYMMDD') || '-' || p.seq
            ELSE 'VCB' || to_char(p.pay_date, 'YYMMDD') || replace(st.code, '-', '') || p.seq END,
       'CONFIRMED', acc.id, p.pay_date::timestamptz + interval '15 hours'
FROM app.invoices i
JOIN app.stores st ON st.id = i.store_id
CROSS JOIN (SELECT id FROM app.users WHERE email = 'accountant@franchise.local') acc
CROSS JOIN LATERAL (
    SELECT * FROM (VALUES
        (1, CASE WHEN i.status = 'PAID' AND right(st.code, 1)::int % 3 = 0
                 THEN round(i.paid_amount * 0.6) ELSE i.paid_amount END,
         least((i.issued_at + interval '5 days')::date, current_date - 1)),
        (2, i.paid_amount - round(i.paid_amount * 0.6),
         least((i.issued_at + interval '7 days')::date, current_date - 1))
    ) v(seq, amount, pay_date)
    WHERE i.paid_amount > 0
      AND (v.seq = 1 OR (i.status = 'PAID' AND right(st.code, 1)::int % 3 = 0))
) p
WHERE p.amount > 0;

-- Một thanh toán nhập sai đã bị đảo (Cầu Giấy, tháng trước); khoản đúng đã ghi ở trên
INSERT INTO app.payments (payment_no, invoice_id, amount, payment_date, method, reference_no,
                          status, recorded_by, reversed_by, reversed_at, reversal_reason, created_at)
SELECT 'TT-' || to_char(i.period_month, 'YYYYMM') || '-' || st.code || '-SAI', i.id,
       round(i.invoice_total / 10.0) * 10, (i.issued_at + interval '4 days')::date, 'BANK_TRANSFER',
       'VCB' || to_char(i.issued_at + interval '4 days', 'YYMMDD') || 'NHAPSAI', 'REVERSED', acc.id, acc.id,
       i.issued_at + interval '4 days 16 hours', 'Nhập nhầm số tiền, chứng từ ngân hàng là của cửa hàng khác.',
       i.issued_at + interval '4 days 15 hours'
FROM app.invoices i
JOIN app.stores st ON st.id = i.store_id
CROSS JOIN (SELECT id FROM app.users WHERE email = 'accountant@franchise.local') acc
WHERE st.code = 'CH0002' AND i.period_month = (date_trunc('month', current_date) - interval '1 month')::date;

-- Khoản điều chỉnh chờ áp vào hóa đơn tháng này
INSERT INTO app.billing_adjustments (store_id, source_period, amount, reason, created_by, created_at)
SELECT st.id, date_trunc('month', current_date)::date, v.amount, v.reason, acc.id, now() - make_interval(days => v.days_ago)
FROM (VALUES
    ('CH0008', 1500000, 'Phí đào tạo barista cho 3 nhân viên mới tại trung tâm đào tạo của thương hiệu.', 9),
    ('CH0009', -800000, 'Giảm trừ phí dịch vụ do hệ thống POS gián đoạn 2 ngày.', 5),
    ('CH0001', 2200000, 'Phí in ấn bộ nhận diện mới (menu, biển bảng) theo đợt thay đổi thương hiệu.', 3)
) AS v(code, amount, reason, days_ago)
JOIN app.stores st ON st.code = v.code
CROSS JOIN (SELECT id FROM app.users WHERE email = 'accountant@franchise.local') acc;

-- ---------------------------------------------------------------------------
-- 8. Thông báo
-- ---------------------------------------------------------------------------
INSERT INTO app.notifications (user_id, notification_type, title, message, entity_type, entity_id, dedupe_key, read_at, created_at)
SELECT st.owner_id, 'INVOICE_ISSUED', 'Hóa đơn đã phát hành',
       'Hóa đơn ' || i.invoice_no || ' đã được phát hành, tổng ' || to_char(i.invoice_total, 'FM999G999G999G999') || ' đ, hạn thanh toán ' || to_char(i.due_date, 'DD/MM/YYYY') || '.',
       'INVOICE', i.id, 'INVOICE_ISSUED:' || i.id,
       CASE WHEN i.status = 'PAID' THEN i.issued_at + interval '1 day' END, i.issued_at
FROM app.invoices i JOIN app.stores st ON st.id = i.store_id
WHERE i.period_month >= (date_trunc('month', current_date) - interval '2 months')::date;

INSERT INTO app.notifications (user_id, notification_type, title, message, entity_type, entity_id, dedupe_key, created_at)
SELECT st.owner_id, 'INVOICE_OVERDUE', 'Hóa đơn quá hạn',
       'Hóa đơn ' || i.invoice_no || ' đã quá hạn thanh toán, còn nợ ' || to_char(i.outstanding_amount, 'FM999G999G999G999') || ' đ.',
       'INVOICE', i.id, 'INVOICE_OVERDUE:' || i.id, i.due_date + interval '1 day 8 hours'
FROM app.invoices i JOIN app.stores st ON st.id = i.store_id
WHERE i.status = 'OVERDUE';

INSERT INTO app.notifications (user_id, notification_type, title, message, entity_type, entity_id, dedupe_key, read_at, created_at)
SELECT st.owner_id, 'PAYMENT_CONFIRMED', 'Đã ghi nhận thanh toán',
       'Thanh toán ' || p.payment_no || ' số tiền ' || to_char(p.amount, 'FM999G999G999G999') || ' đ đã được ghi nhận.',
       'PAYMENT', p.id, 'PAYMENT_CONFIRMED:' || p.id, p.created_at + interval '2 hours', p.created_at
FROM app.payments p JOIN app.invoices i ON i.id = p.invoice_id JOIN app.stores st ON st.id = i.store_id
WHERE p.status = 'CONFIRMED' AND i.period_month = (date_trunc('month', current_date) - interval '1 month')::date;

INSERT INTO app.notifications (user_id, notification_type, title, message, entity_type, entity_id, dedupe_key, created_at)
SELECT st.owner_id,
       CASE rv.status WHEN 'REJECTED' THEN 'REVENUE_REJECTED' ELSE 'REVENUE_ADJUSTMENT_REQUESTED' END,
       CASE rv.status WHEN 'REJECTED' THEN 'Doanh thu bị từ chối' ELSE 'Yêu cầu điều chỉnh doanh thu' END,
       coalesce(rv.review_note, rv.adjustment_reason) || ' (ngày ' || to_char(rv.business_date, 'DD/MM/YYYY') || ')',
       'REVENUE', rv.id, rv.status || ':' || rv.id, coalesce(rv.adjustment_requested_at, rv.reviewed_at)
FROM app.revenues rv JOIN app.stores st ON st.id = rv.store_id
WHERE rv.status IN ('REJECTED', 'ADJUSTMENT_REQUESTED');

INSERT INTO app.notifications (user_id, notification_type, title, message, entity_type, entity_id, dedupe_key, created_at)
SELECT st.owner_id, 'REVENUE_OVERDUE', 'Chậm báo cáo doanh thu',
       'Cửa hàng ' || st.name || ' chưa nộp doanh thu ngày ' || to_char(current_date - 1, 'DD/MM/YYYY') || '.',
       'STORE', st.id, 'REVENUE_OVERDUE:' || st.id || ':' || (current_date - 1),
       (current_date - 1) + interval '23 hours'
FROM app.stores st WHERE st.code = 'CH0013';

INSERT INTO app.notifications (user_id, notification_type, title, message, entity_type, entity_id, dedupe_key, read_at, created_at)
SELECT st.owner_id, 'PROMOTION_STARTED', 'Khuyến mãi bắt đầu',
       'Chương trình "' || pr.name || '" áp dụng từ ' || to_char(pr.start_date, 'DD/MM/YYYY') || ' đến ' || to_char(pr.end_date, 'DD/MM/YYYY') || '. Thương hiệu chịu toàn bộ chi phí giảm giá.',
       'PROMOTION', pr.id, 'PROMOTION_STARTED:' || pr.id || ':' || st.owner_id,
       CASE WHEN right(st.code, 1)::int % 2 = 0 THEN pr.start_date + interval '10 hours' END,
       pr.start_date + interval '8 hours'
FROM app.promotions pr CROSS JOIN app.stores st
WHERE pr.status = 'ACTIVE' AND st.status = 'ACTIVE'
ON CONFLICT (dedupe_key) DO NOTHING;

INSERT INTO app.notifications (user_id, notification_type, title, message, entity_type, entity_id, dedupe_key, created_at)
SELECT fa.applicant_id, 'APPLICATION_APPROVED', 'Hồ sơ được duyệt',
       'Hồ sơ "' || fa.proposed_store_name || '" đã được duyệt. Vui lòng hoàn tất ký hợp đồng và thanh toán phí ban đầu.',
       'APPLICATION', fa.id, 'APPROVE_APPLICATION:' || fa.id, fa.reviewed_at
FROM app.franchise_applications fa WHERE fa.status = 'APPROVED' AND fa.converted_at IS NULL;

INSERT INTO app.notifications (user_id, notification_type, title, message, entity_type, entity_id, dedupe_key, read_at, created_at)
SELECT fa.applicant_id, 'APPLICATION_REJECTED', 'Hồ sơ bị từ chối', fa.review_note,
       'APPLICATION', fa.id, 'REJECT_APPLICATION:' || fa.id, fa.reviewed_at + interval '1 day', fa.reviewed_at
FROM app.franchise_applications fa WHERE fa.status = 'REJECTED';

-- ---------------------------------------------------------------------------
-- 9. Nhật ký thao tác (các sự kiện chính)
-- ---------------------------------------------------------------------------
INSERT INTO app.audit_logs (actor_id, action, entity_type, entity_id, new_values, reason, created_at)
SELECT a.id, e.action, e.entity_type, e.entity_id, e.new_values, e.reason, e.created_at
FROM (SELECT id FROM app.users WHERE email = 'admin@franchise.local') a
CROSS JOIN LATERAL (
    SELECT 'CREATE_CONTRACT' AS action, 'CONTRACT' AS entity_type, c.id AS entity_id,
           jsonb_build_object('contract_no', c.contract_no, 'store_code', c.store_code, 'status', 'DRAFT') AS new_values,
           NULL::text AS reason, c.created_at
    FROM app.contracts c
    UNION ALL
    SELECT 'ACTIVATE_CONTRACT', 'CONTRACT', c.id,
           jsonb_build_object('status', 'ACTIVE', 'store_id', c.store_id),
           'Đã ký và thu đủ phí nhượng quyền ban đầu', c.updated_at
    FROM app.contracts c WHERE c.status = 'ACTIVE'
    UNION ALL
    SELECT 'CREATE_STORE', 'STORE', st.id,
           jsonb_build_object('code', st.code, 'status', 'INACTIVE'), 'Tạo cửa hàng tự động khi lập hợp đồng', st.created_at
    FROM app.stores st
    UNION ALL
    SELECT 'CREATE_PROMOTION', 'PROMOTION', pr.id,
           jsonb_build_object('name', pr.name, 'status', pr.status), NULL, pr.created_at
    FROM app.promotions pr
) e;

INSERT INTO app.audit_logs (actor_id, action, entity_type, entity_id, new_values, created_at)
SELECT i.created_by, 'ISSUE_INVOICE', 'INVOICE', i.id,
       jsonb_build_object('invoice_no', i.invoice_no, 'total', i.invoice_total), i.issued_at
FROM app.invoices i;

INSERT INTO app.audit_logs (actor_id, action, entity_type, entity_id, new_values, reason, created_at)
SELECT p.recorded_by, CASE p.status WHEN 'REVERSED' THEN 'REVERSE_PAYMENT' ELSE 'RECORD_PAYMENT' END,
       'PAYMENT', p.id, jsonb_build_object('payment_no', p.payment_no, 'amount', p.amount),
       p.reversal_reason, coalesce(p.reversed_at, p.created_at)
FROM app.payments p;

COMMIT;
