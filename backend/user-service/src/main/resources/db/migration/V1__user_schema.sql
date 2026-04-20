-- User Service şeması. auth-service ile aynı 'users' tablosunu paylaşır;
-- bu migration idempotenttir ve profil alanlarını ekler, uzman profillerini oluşturur.

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(512);

CREATE TABLE IF NOT EXISTS industries (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(120) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS skills (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(120) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expert_profiles (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
    industry_id UUID REFERENCES industries (id) ON DELETE SET NULL,
    headline VARCHAR(160),
    bio TEXT,
    company VARCHAR(160),
    years_of_experience INTEGER NOT NULL DEFAULT 0,
    hourly_rate NUMERIC(10, 2),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    average_rating NUMERIC(3, 2) NOT NULL DEFAULT 0.00,
    total_sessions INTEGER NOT NULL DEFAULT 0,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expert_profiles_industry ON expert_profiles (industry_id);
CREATE INDEX IF NOT EXISTS idx_expert_profiles_rating ON expert_profiles (average_rating DESC);
CREATE INDEX IF NOT EXISTS idx_expert_profiles_available ON expert_profiles (is_available);

CREATE TABLE IF NOT EXISTS expert_profile_skills (
    expert_profile_id UUID NOT NULL REFERENCES expert_profiles (id) ON DELETE CASCADE,
    skill_id UUID NOT NULL REFERENCES skills (id) ON DELETE CASCADE,
    PRIMARY KEY (expert_profile_id, skill_id)
);

CREATE INDEX IF NOT EXISTS idx_expert_profile_skills_skill ON expert_profile_skills (skill_id);
