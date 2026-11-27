-- Reference data required by authorization and seed scripts.
INSERT INTO app.roles (code, name)
VALUES
    ('ADMIN', 'Administrator'),
    ('STORE_OWNER', 'Store Owner'),
    ('ACCOUNTANT', 'Accountant')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;
