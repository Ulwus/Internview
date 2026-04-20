-- ──────────────────────────────────────────────────────────
-- Week 6 · Booking Service · initial schema
--
-- Aynı PostgreSQL instance'ı auth-service ve user-service ile
-- paylaşıldığı için booking-service'e özgü DDL yalnızca kendi
-- tablolarını oluşturur.  Tüm statement'lar idempotent.
-- ──────────────────────────────────────────────────────────

-- availability_slots: bir uzmanın (expert_profiles.id) rezerve
-- edilebilir zaman aralıkları
CREATE TABLE IF NOT EXISTS availability_slots (
    id          UUID        PRIMARY KEY,
    expert_id   UUID        NOT NULL,
    start_time  TIMESTAMPTZ NOT NULL,
    end_time    TIMESTAMPTZ NOT NULL,
    is_booked   BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT availability_slot_time_check CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_availability_slots_expert_id
    ON availability_slots (expert_id);

CREATE INDEX IF NOT EXISTS idx_availability_slots_expert_open
    ON availability_slots (expert_id, start_time)
    WHERE is_booked = FALSE;

-- bookings: aday (users.id) × uzman (expert_profiles.id) × slot
CREATE TABLE IF NOT EXISTS bookings (
    id            UUID        PRIMARY KEY,
    candidate_id  UUID        NOT NULL,
    expert_id     UUID        NOT NULL,
    slot_id       UUID        NOT NULL,
    status        VARCHAR(32) NOT NULL,
    scheduled_start TIMESTAMPTZ NOT NULL,
    scheduled_end   TIMESTAMPTZ NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT bookings_status_check CHECK (
        status IN ('PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED')
    ),
    CONSTRAINT bookings_time_check CHECK (scheduled_end > scheduled_start),
    CONSTRAINT bookings_slot_unique UNIQUE (slot_id)
);

CREATE INDEX IF NOT EXISTS idx_bookings_candidate_id
    ON bookings (candidate_id);

CREATE INDEX IF NOT EXISTS idx_bookings_expert_id
    ON bookings (expert_id);

CREATE INDEX IF NOT EXISTS idx_bookings_status
    ON bookings (status);
