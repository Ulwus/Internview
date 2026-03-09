# Domain Model

## 3.1 Domain Overview

Internview'in domain modeli, bir adayın platforma kaydolmasından, uzman ile mülakat yapıp AI destekli performans raporu almasına kadarki tüm iş sürecini kapsayan entity'lerden oluşur.

### Ana Kavramlar (Bounded Contexts)

```mermaid
graph LR
    subgraph "Identity & Access"
        User["User"]
        Role["Role"]
    end

    subgraph "Expert Management"
        ExpertProfile["Expert Profile"]
        Skill["Skill"]
        Industry["Industry"]
    end

    subgraph "Scheduling"
        AvailabilitySlot["Availability Slot"]
        Booking["Booking"]
    end

    subgraph "Interview & Analysis"
        InterviewSession["Interview Session"]
        InterviewAnalysis["Interview Analysis"]
    end

    User --> ExpertProfile
    User --> Booking
    ExpertProfile --> Skill
    ExpertProfile --> Industry
    ExpertProfile --> AvailabilitySlot
    Booking --> AvailabilitySlot
    Booking --> InterviewSession
    InterviewSession --> InterviewAnalysis
```

---

## 3.2 Core Entities

### User

Sistemdeki tüm kullanıcıları temsil eder. Bir kullanıcı hem aday hem uzman rolüne sahip olabilir.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | `UUID` | Benzersiz kullanıcı kimliği (Primary Key) |
| `email` | `VARCHAR(255)` | Kullanıcı e-posta adresi (Unique) |
| `password_hash` | `VARCHAR(255)` | BCrypt ile hashlenmiş parola |
| `first_name` | `VARCHAR(100)` | Ad |
| `last_name` | `VARCHAR(100)` | Soyad |
| `avatar_url` | `TEXT` | Profil fotoğrafı URL'i |
| `created_at` | `TIMESTAMP` | Oluşturulma tarihi |
| `updated_at` | `TIMESTAMP` | Son güncelleme tarihi |

### Role

Kullanıcıya atanabilen rolleri tanımlar. Many-to-Many ilişki ile bir kullanıcı birden fazla role sahip olabilir.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | `BIGINT` | Primary Key |
| `name` | `VARCHAR(50)` | Rol adı: `CANDIDATE`, `EXPERT`, `ADMIN` |

**Ara Tablo — `user_roles`:**

| Alan | Tip | Açıklama |
|------|-----|----------|
| `user_id` | `UUID` | FK → `users.id` |
| `role_id` | `BIGINT` | FK → `roles.id` |

### ExpertProfile

Uzman rolüne sahip kullanıcıların detaylı profil bilgilerini içerir.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | `UUID` | Primary Key |
| `user_id` | `UUID` | FK → `users.id` (One-to-One) |
| `bio` | `TEXT` | Uzman biyografisi |
| `current_company` | `VARCHAR(255)` | Çalıştığı şirket |
| `title` | `VARCHAR(255)` | Ünvanı (Sr. Software Engineer, CTO vb.) |
| `experience_years` | `INTEGER` | Toplam deneyim yılı |
| `rating` | `DECIMAL(3,2)` | Ortalama değerlendirme puanı (0.00 – 5.00) |

### Skill

Uzmanların sahip olduğu teknik yetenekleri temsil eder (Many-to-Many).

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | `BIGINT` | Primary Key |
| `name` | `VARCHAR(100)` | Yetenek adı: Java, React, Flutter, System Design vb. |

**Ara Tablo — `expert_skills`:**

| Alan | Tip | Açıklama |
|------|-----|----------|
| `expert_id` | `UUID` | FK → `expert_profiles.id` |
| `skill_id` | `BIGINT` | FK → `skills.id` |

### Industry

Uzmanların uzmanlık sektörlerini tanımlar (Many-to-Many).

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | `BIGINT` | Primary Key |
| `name` | `VARCHAR(100)` | Sektör adı: Fintech, E-Commerce, HealthTech vb. |

**Ara Tablo — `expert_industries`:**

| Alan | Tip | Açıklama |
|------|-----|----------|
| `expert_id` | `UUID` | FK → `expert_profiles.id` |
| `industry_id` | `BIGINT` | FK → `industries.id` |

### AvailabilitySlot

Uzmanların müsait oldukları zaman aralıklarını tanımlar.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | `UUID` | Primary Key |
| `expert_id` | `UUID` | FK → `expert_profiles.id` |
| `start_time` | `TIMESTAMP` | Slot başlangıç zamanı |
| `end_time` | `TIMESTAMP` | Slot bitiş zamanı |
| `is_booked` | `BOOLEAN` | Slot rezerve edildi mi? (Default: `false`) |

### Booking

Aday ile uzman arasındaki randevuyu temsil eder.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | `UUID` | Primary Key |
| `candidate_id` | `UUID` | FK → `users.id` (Randevu alan aday) |
| `expert_id` | `UUID` | FK → `expert_profiles.id` (Randevu verilen uzman) |
| `slot_id` | `UUID` | FK → `availability_slots.id` (Kapatılan slot) |
| `status` | `ENUM` | `PENDING` → `CONFIRMED` → `COMPLETED` / `CANCELLED` |
| `created_at` | `TIMESTAMP` | Randevu oluşturulma zamanı |

### InterviewSession

Bir randevunun gerçekleşen mülakat oturumunu temsil eder.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | `UUID` | Primary Key |
| `booking_id` | `UUID` | FK → `bookings.id` (One-to-One) |
| `room_url` | `TEXT` | WebRTC oda bağlantı adresi |
| `start_time` | `TIMESTAMP` | Oturum başlangıç zamanı |
| `end_time` | `TIMESTAMP` | Oturum bitiş zamanı |
| `recorded_video_url` | `TEXT` | S3'teki video kaydının URL'i |
| `status` | `ENUM` | `WAITING` → `IN_PROGRESS` → `COMPLETED` |

### InterviewAnalysis

AI tarafından üretilen mülakat analiz raporunu temsil eder.

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | `UUID` | Primary Key |
| `session_id` | `UUID` | FK → `interview_sessions.id` (One-to-One) |
| `transcript` | `TEXT` | Konuşmanın tam metin dökümü |
| `analysis_result` | `JSONB` | Yapılandırılmış analiz metrikleri (aşağıya bakınız) |
| `created_at` | `TIMESTAMP` | Analiz tamamlanma zamanı |

**`analysis_result` JSONB Yapısı:**

```json
{
  "wpm": 142,
  "total_words": 2840,
  "duration_seconds": 1200,
  "pause_count": 23,
  "pause_ratio": 0.12,
  "filler_words": {
    "eee": 8,
    "hmm": 5,
    "yani": 12,
    "şey": 6
  },
  "filler_word_ratio": 0.011,
  "overall_score": 78.5
}
```

---

## 3.3 Relationships

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : has
    ROLES ||--o{ USER_ROLES : has
    USERS ||--o| EXPERT_PROFILES : "has (if expert)"
    EXPERT_PROFILES ||--o{ EXPERT_SKILLS : has
    SKILLS ||--o{ EXPERT_SKILLS : has
    EXPERT_PROFILES ||--o{ EXPERT_INDUSTRIES : has
    INDUSTRIES ||--o{ EXPERT_INDUSTRIES : has
    EXPERT_PROFILES ||--o{ AVAILABILITY_SLOTS : offers
    USERS ||--o{ BOOKINGS : "creates (as candidate)"
    EXPERT_PROFILES ||--o{ BOOKINGS : "receives"
    AVAILABILITY_SLOTS ||--o| BOOKINGS : "booked by"
    BOOKINGS ||--o| INTERVIEW_SESSIONS : starts
    INTERVIEW_SESSIONS ||--o| INTERVIEW_ANALYSIS : generates
```

### İlişki Özeti

| İlişki | Tip | Açıklama |
|--------|-----|----------|
| User ↔ Role | Many-to-Many | Bir kullanıcı birden fazla role sahip olabilir |
| User ↔ ExpertProfile | One-to-One | Sadece uzman rolündeki kullanıcılar |
| ExpertProfile ↔ Skill | Many-to-Many | Bir uzmanın birden fazla yeteneği olabilir |
| ExpertProfile ↔ Industry | Many-to-Many | Bir uzman birden fazla sektörde aktif olabilir |
| ExpertProfile ↔ AvailabilitySlot | One-to-Many | Uzman birden fazla müsaitlik aralığı tanımlayabilir |
| User ↔ Booking | One-to-Many | Aday birden fazla randevu oluşturabilir |
| ExpertProfile ↔ Booking | One-to-Many | Uzman birden fazla randevu alabilir |
| AvailabilitySlot ↔ Booking | One-to-One | Bir slot yalnızca bir randevuya atanabilir |
| Booking ↔ InterviewSession | One-to-One | Her randevu bir mülakat oturumuna karşılık gelir |
| InterviewSession ↔ InterviewAnalysis | One-to-One | Her oturum bir AI analiz raporu üretir |

---

## 3.4 ER Diagram

Aşağıdaki diyagram tüm entity'lerin veritabanı tablo temsillerini ve aralarındaki foreign key ilişkilerini göstermektedir.

```mermaid
erDiagram
    users {
        UUID id PK
        VARCHAR email UK
        VARCHAR password_hash
        VARCHAR first_name
        VARCHAR last_name
        TEXT avatar_url
        TIMESTAMP created_at
        TIMESTAMP updated_at
    }

    roles {
        BIGINT id PK
        VARCHAR name
    }

    user_roles {
        UUID user_id FK
        BIGINT role_id FK
    }

    expert_profiles {
        UUID id PK
        UUID user_id FK
        TEXT bio
        VARCHAR current_company
        VARCHAR title
        INTEGER experience_years
        DECIMAL rating
    }

    skills {
        BIGINT id PK
        VARCHAR name
    }

    expert_skills {
        UUID expert_id FK
        BIGINT skill_id FK
    }

    industries {
        BIGINT id PK
        VARCHAR name
    }

    expert_industries {
        UUID expert_id FK
        BIGINT industry_id FK
    }

    availability_slots {
        UUID id PK
        UUID expert_id FK
        TIMESTAMP start_time
        TIMESTAMP end_time
        BOOLEAN is_booked
    }

    bookings {
        UUID id PK
        UUID candidate_id FK
        UUID expert_id FK
        UUID slot_id FK
        ENUM status
        TIMESTAMP created_at
    }

    interview_sessions {
        UUID id PK
        UUID booking_id FK
        TEXT room_url
        TIMESTAMP start_time
        TIMESTAMP end_time
        TEXT recorded_video_url
        ENUM status
    }

    interview_analysis {
        UUID id PK
        UUID session_id FK
        TEXT transcript
        JSONB analysis_result
        TIMESTAMP created_at
    }

    users ||--o{ user_roles : ""
    roles ||--o{ user_roles : ""
    users ||--o| expert_profiles : ""
    expert_profiles ||--o{ expert_skills : ""
    skills ||--o{ expert_skills : ""
    expert_profiles ||--o{ expert_industries : ""
    industries ||--o{ expert_industries : ""
    expert_profiles ||--o{ availability_slots : ""
    users ||--o{ bookings : ""
    expert_profiles ||--o{ bookings : ""
    availability_slots ||--o| bookings : ""
    bookings ||--o| interview_sessions : ""
    interview_sessions ||--o| interview_analysis : ""
```
