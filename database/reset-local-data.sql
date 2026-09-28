-- CHỈ DÙNG CHO MÔI TRƯỜNG LOCAL.
-- Xóa dữ liệu vận hành nhưng giữ nguyên schema, migration và danh mục role.
BEGIN;
TRUNCATE TABLE app.users RESTART IDENTITY CASCADE;
COMMIT;
