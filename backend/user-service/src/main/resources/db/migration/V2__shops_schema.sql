-- Marketplace Shops şeması (user-service)

CREATE TABLE IF NOT EXISTS expert_shops (
    id UUID PRIMARY KEY,
    expert_user_id UUID NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
    industry_id UUID REFERENCES industries (id) ON DELETE SET NULL,
    description TEXT,
    years_of_experience INTEGER NOT NULL DEFAULT 0,
    hourly_rate NUMERIC(10, 2),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expert_shops_industry ON expert_shops (industry_id);
CREATE INDEX IF NOT EXISTS idx_expert_shops_price ON expert_shops (hourly_rate);
CREATE INDEX IF NOT EXISTS idx_expert_shops_published ON expert_shops (is_published);

CREATE TABLE IF NOT EXISTS expert_shop_skills (
    expert_shop_id UUID NOT NULL REFERENCES expert_shops (id) ON DELETE CASCADE,
    skill_id UUID NOT NULL REFERENCES skills (id) ON DELETE CASCADE,
    PRIMARY KEY (expert_shop_id, skill_id)
);

CREATE INDEX IF NOT EXISTS idx_expert_shop_skills_skill ON expert_shop_skills (skill_id);

