# API Design

## 4.1 API Principles

Internview API'leri aşağıdaki tasarım prensiplerine göre geliştirilmektedir:

| Prensip | Açıklama |
|---------|----------|
| **RESTful Design** | Resource-based URL yapısı, HTTP method semantiği (GET, POST, PUT, PATCH, DELETE) |
| **Stateless API** | Sunucu tarafında oturum tutulmaz; her istek JWT token ile kendi kimliğini taşır |
| **JSON Communication** | Tüm request/response body'leri JSON formatındadır |
| **Consistent Error Handling** | Standart hata formatı ile tutarlı hata yanıtları |
| **API Gateway Routing** | Tüm istekler Spring Cloud Gateway üzerinden ilgili servise yönlendirilir |

> **Alan adlandırma:** İç domain DTO'larında (user-service, booking-service) alan adları **camelCase** olarak JSON'a dönüşür (`firstName`, `scheduledStart`, `expertId`). Auth servisi DTO'ları ise Jackson `@JsonProperty` ile açıkça **snake_case** olarak döner (`user_id`, `access_token`, `refresh_token`, `first_name`, `last_name`, `expires_in`).

### Standart Yanıt Formatı

**Başarılı Yanıt:**
```json
{
  "success": true,
  "data": { ... },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

**Hata Yanıtı:**
```json
{
  "success": false,
  "error": {
    "code": "BOOKING_SLOT_UNAVAILABLE",
    "message": "Seçilen slot başka bir randevu tarafından alınmış."
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### Authentication Header

Korumalı endpoint'lere erişim için her istekte JWT token gönderilmelidir:

```
Authorization: Bearer <jwt_token>
```

---

## 4.2 Authentication API

**Service:** Auth Service
**Gateway Base Path:** `/auth` (Gateway `StripPrefix=1` ile auth-service'in kök path'ine yönlendirir)

### POST /auth/register

Yeni kullanıcı kaydı oluşturur.

**Request Body:**
```json
{
  "email": "aday@example.com",
  "password": "SecurePass123!",
  "first_name": "Ali",
  "last_name": "Yılmaz",
  "role": "CANDIDATE"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "aday@example.com",
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "dGhpcyBpcyBhIHJlZnJl...",
    "expires_in": 3600
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### POST /auth/login

Var olan kullanıcının kimlik doğrulamasını yapar ve JWT token döner.

**Request Body:**
```json
{
  "email": "aday@example.com",
  "password": "SecurePass123!"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "dGhpcyBpcyBhIHJlZnJl...",
    "expires_in": 3600
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### POST /auth/refresh

Süresi dolan access token'ı yenilemek için refresh token gönderilir.

**Request Body:**
```json
{
  "refresh_token": "dGhpcyBpcyBhIHJlZnJl..."
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_in": 3600
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### GET /auth/me

Authenticated kullanıcının JWT token üzerinden kimlik bilgilerini döner.

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "aday@example.com",
    "first_name": "Ali",
    "last_name": "Yılmaz",
    "roles": ["CANDIDATE"]
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### GET /auth/admin/ping

**Role:** `ADMIN` (demo endpoint — sadece admin rolü doğrulaması için).

---

## 4.3 User API

**Service:** User Service
**Gateway Base Path:** `/users` (Gateway `StripPrefix` kullanmaz; controller zaten `@RequestMapping("/users")` ile path'i taşır)

### GET /users/profile

Authenticated kullanıcının kendi profil bilgilerini getirir.

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "aday@example.com",
    "firstName": "Ali",
    "lastName": "Yılmaz",
    "avatarUrl": "https://s3.amazonaws.com/internview/avatars/ali.jpg",
    "role": "CANDIDATE",
    "createdAt": "2026-04-01T10:00:00Z",
    "updatedAt": "2026-04-20T12:00:00Z"
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### PUT /users/profile

Kullanıcının kendi profil bilgilerini günceller (aday veya uzman). Tüm alanlar opsiyoneldir — sadece gönderilenler güncellenir.

**Request Body:**
```json
{
  "firstName": "Ali",
  "lastName": "Yılmaz",
  "avatarUrl": "https://s3.amazonaws.com/internview/avatars/ali_v2.jpg"
}
```

**Response (200 OK):** `UserProfileResponse` (GET /users/profile ile aynı şema).

---

## 4.4 Expert API

**Service:** User Service
**Gateway Base Path:** `/experts`

### GET /experts

Platformdaki uzmanları sektör, yetenek, puan ve müsaitlik bazlı filtreleme ile listeler. Sayfalama desteklenir.

**Query Parameters:**

| Parametre | Tip | Zorunlu | Açıklama |
|-----------|-----|---------|----------|
| `industry` | String | Hayır | Sektör slug'ı (`fintech`, `healthtech` vb.) |
| `skill` | String (tekrarlanabilir) | Hayır | Yetenek slug filtresi (`skill=java&skill=react`) |
| `min_rating` | Decimal | Hayır | Minimum ortalama puan (0.0 – 5.0) |
| `max_hourly_rate` | Decimal | Hayır | Maksimum saatlik ücret |
| `is_available` | Boolean | Hayır | Sadece müsait uzmanları döner |
| `search` | String | Hayır | Ad/soyad/başlık içinde metin araması |
| `page` | Integer | Hayır | Sayfa numarası (default: `0`) |
| `size` | Integer | Hayır | Sayfa boyutu (default: `20`, max: `100`) |
| `sort` | String | Hayır | `field,direction` formatı (default: `averageRating,desc`) |

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "content": [
      {
        "id": "660e8400-e29b-41d4-a716-446655440001",
        "userId": "550e8400-e29b-41d4-a716-446655440000",
        "firstName": "Mehmet",
        "lastName": "Kaya",
        "avatarUrl": "https://...",
        "headline": "Senior Backend Engineer @ Google",
        "company": "Google",
        "industry": { "id": "...", "name": "Fintech", "slug": "fintech" },
        "skills": [
          { "id": "...", "name": "Java", "slug": "java" },
          { "id": "...", "name": "Spring Boot", "slug": "spring-boot" }
        ],
        "yearsOfExperience": 8,
        "hourlyRate": 150.00,
        "currency": "USD",
        "averageRating": 4.85,
        "totalSessions": 42,
        "isVerified": true,
        "isAvailable": true
      }
    ],
    "page": 0,
    "size": 20,
    "totalElements": 142,
    "totalPages": 8
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### GET /experts/{id}

Belirli bir uzmanın detaylı profil bilgilerini getirir. `{id}` — `expert_profiles.id` UUID'sidir.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "email": "mehmet@example.com",
    "firstName": "Mehmet",
    "lastName": "Kaya",
    "avatarUrl": "https://...",
    "headline": "Senior Backend Engineer @ Google",
    "bio": "8 yıllık yazılım deneyimi. Google ve Amazon'da backend mühendisliği.",
    "company": "Google",
    "industry": { "id": "...", "name": "Fintech", "slug": "fintech" },
    "skills": [
      { "id": "...", "name": "Java", "slug": "java" }
    ],
    "yearsOfExperience": 8,
    "hourlyRate": 150.00,
    "currency": "USD",
    "averageRating": 4.85,
    "totalSessions": 42,
    "isVerified": true,
    "isAvailable": true,
    "createdAt": "2026-04-01T10:00:00Z",
    "updatedAt": "2026-04-20T12:00:00Z"
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### GET /experts/me

**Role:** `EXPERT`. Token sahibinin kendi uzman profilini `ExpertDetailResponse` formatında döner.

### PUT /experts/me

**Role:** `EXPERT`. Uzmanın kendi profilini günceller. Tüm alanlar opsiyoneldir.

**Request Body:**
```json
{
  "headline": "Staff Backend Engineer",
  "bio": "10+ yıl deneyim...",
  "company": "Meta",
  "industrySlug": "fintech",
  "skillSlugs": ["java", "kotlin", "system-design"],
  "yearsOfExperience": 10,
  "hourlyRate": 200.00,
  "currency": "USD",
  "isAvailable": true
}
```

**Response (200 OK):** Güncellenmiş `ExpertDetailResponse`.

---

## 4.5 Skill & Industry API

**Service:** User Service

### GET /skills

Tüm yetenek kayıtlarını listeler (filtre/pagination yok).

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    { "id": "...", "name": "Java", "slug": "java" },
    { "id": "...", "name": "React", "slug": "react" }
  ],
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### GET /industries

Tüm sektör kayıtlarını listeler.

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    { "id": "...", "name": "Fintech", "slug": "fintech" },
    { "id": "...", "name": "E-Commerce", "slug": "e-commerce" }
  ],
  "timestamp": "2026-04-20T12:00:00Z"
}
```

---

## 4.6 Availability API

**Service:** Booking Service
**Gateway Base Path:** Özel route'lar — `AvailabilityController` sınıf seviyesinde `@RequestMapping` kullanmadığından Gateway aşağıdaki path'leri `StripPrefix` olmadan doğrudan servis'e iletir:
- `/availability/**`
- `/experts/me/availability/**`

### GET /availability/{expertId}

Uzmanın henüz rezerve edilmemiş (`is_booked=false`) açık slot'larını döner.

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "770e8400-e29b-41d4-a716-446655440002",
      "expertId": "550e8400-...",
      "startTime": "2026-04-21T10:00:00Z",
      "endTime": "2026-04-21T11:00:00Z",
      "booked": false
    }
  ],
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### GET /experts/me/availability

**Role:** `EXPERT`. Uzmanın kendi slot'larını (rezerve edilmiş + açık) listeler.

### POST /experts/me/availability

**Role:** `EXPERT`. Yeni bir müsaitlik slot'u oluşturur.

**Request Body:**
```json
{
  "startTime": "2026-04-21T10:00:00Z",
  "endTime": "2026-04-21T11:00:00Z"
}
```

**Response (201 Created):** `SlotResponse`.

### DELETE /experts/me/availability/{slotId}

**Role:** `EXPERT`. Uzmanın kendi slot'unu siler. Slot zaten rezerveyse `409 Conflict` döner.

---

## 4.7 Booking API

**Service:** Booking Service
**Gateway Base Path:** `/bookings`

### POST /bookings

**Role:** `CANDIDATE`. Adayın, uzmanın boş bir slot'unu rezerve ederek booking oluşturması. Çifte rezervasyonu engellemek için Redis Distributed Lock mekanizması devrededir.

**Request Body:**
```json
{
  "expertId": "550e8400-e29b-41d4-a716-446655440001",
  "slotId": "770e8400-e29b-41d4-a716-446655440002"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "880e8400-e29b-41d4-a716-446655440003",
    "candidateId": "550e8400-...",
    "expertId": "660e8400-...",
    "slotId": "770e8400-...",
    "status": "CONFIRMED",
    "scheduledStart": "2026-04-21T10:00:00Z",
    "scheduledEnd": "2026-04-21T11:00:00Z"
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

**Error Response (409 Conflict):**
```json
{
  "success": false,
  "error": {
    "code": "BOOKING_SLOT_UNAVAILABLE",
    "message": "Seçilen slot başka bir randevu tarafından alınmış."
  },
  "timestamp": "2026-04-20T12:00:00Z"
}
```

### GET /bookings/{id}

Belirli bir randevunun detay bilgilerini `BookingResponse` formatında döner. İstek sahibi bu booking'in candidate'i ya da expert'i olmalıdır.

### GET /bookings/me/candidate

**Role:** `CANDIDATE`. Token sahibinin aday olarak oluşturduğu tüm randevuları listeler.

**Response (200 OK):** `BookingResponse[]` (timestamp zarflı).

### GET /bookings/me/expert

**Role:** `EXPERT`. Token sahibinin uzman olarak aldığı tüm randevuları listeler.

### PATCH /bookings/{id}/status

Randevunun durumunu günceller. Geçerli değerler: `PENDING`, `CONFIRMED`, `COMPLETED`, `CANCELLED`.

**Request Body:**
```json
{
  "status": "CANCELLED"
}
```

**Response (200 OK):** Güncellenmiş `BookingResponse`.

---

## 4.8 Interview API *(planlanan — henüz implemente edilmedi)*

> Aşağıdaki endpoint'ler roadmap Week 7 (Interview Service + WebRTC) kapsamında hayata geçecektir. Henüz kodda karşılığı yoktur.

**Service:** Interview Service
**Gateway Base Path:** `/interviews`

### POST /interviews/{bookingId}/start

Randevu saati gelmiş olan oturumu başlatır. `interview_sessions` tablosuna kayıt oluşturur ve client'a WebRTC bağlantı bilgilerini döner.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "sessionId": "990e8400-e29b-41d4-a716-446655440004",
    "bookingId": "880e8400-...",
    "roomUrl": "wss://media.internview.io/room/abc123",
    "webrtcConfig": {
      "iceServers": [
        { "urls": "stun:stun.internview.io:3478" },
        { "urls": "turn:turn.internview.io:3478", "username": "user", "credential": "pass" }
      ]
    },
    "status": "IN_PROGRESS",
    "startedAt": "2026-04-21T10:00:00Z"
  }
}
```

### GET /interviews/{id}

Belirli bir mülakat oturumunun bilgilerini getirir.

### GET /interviews/{id}/report

Mülakat tamamlandıktan sonra AI analiz raporunu getirir.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "sessionId": "990e8400-...",
    "analysis": {
      "wpm": 142,
      "totalWords": 2840,
      "durationSeconds": 2700,
      "pauseCount": 23,
      "pauseRatio": 0.12,
      "fillerWords": {
        "eee": 8,
        "hmm": 5,
        "yani": 12,
        "şey": 6
      },
      "fillerWordRatio": 0.011,
      "overallScore": 78.5
    },
    "createdAt": "2026-04-21T11:15:00Z"
  }
}
```

---

> **Not:** Tüm endpoint'lere gelen istekler API Gateway (Spring Cloud Gateway) üzerinden route edilir. Gateway katmanında JWT authentication (BasicAuth filter), rate limiting (Redis RateLimiter) ve request logging uygulanır.
