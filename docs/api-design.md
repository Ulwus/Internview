# API Design

## 4.1 API Principles

Internview API'leri aşağıdaki tasarım prensiplerine göre geliştirilmektedir:

| Prensip | Açıklama |
|---------|----------|
| **RESTful Design** | Resource-based URL yapısı, HTTP method semantiği (GET, POST, PUT, DELETE) |
| **Stateless API** | Sunucu tarafında oturum tutulmaz; her istek JWT token ile kendi kimliğini taşır |
| **JSON Communication** | Tüm request/response body'leri JSON formatındadır |
| **Consistent Error Handling** | Standart hata formatı ile tutarlı hata yanıtları |
| **API Gateway Routing** | Tüm istekler Spring Cloud Gateway üzerinden ilgili servise yönlendirilir |

### Standart Yanıt Formatı

**Başarılı Yanıt:**
```json
{
  "success": true,
  "data": { ... },
  "timestamp": "2026-03-10T00:00:00Z"
}
```

**Hata Yanıtı:**
```json
{
  "success": false,
  "error": {
    "code": "BOOKING_SLOT_UNAVAILABLE",
    "message": "The requested time slot is no longer available."
  },
  "timestamp": "2026-03-10T00:00:00Z"
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
**Base Path:** `/auth`

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
  }
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
  }
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
  }
}
```

---

## 4.3 User API

**Service:** User Service
**Base Path:** `/users`

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
    "first_name": "Ali",
    "last_name": "Yılmaz",
    "avatar_url": "https://s3.amazonaws.com/internview/avatars/ali.jpg",
    "roles": ["CANDIDATE"]
  }
}
```

### PUT /users/profile

Kullanıcının kendi profil bilgilerini günceller (aday veya uzman).

**Request Body:**
```json
{
  "first_name": "Ali",
  "last_name": "Yılmaz",
  "avatar_url": "https://s3.amazonaws.com/internview/avatars/ali_v2.jpg"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "first_name": "Ali",
    "last_name": "Yılmaz",
    "avatar_url": "https://s3.amazonaws.com/internview/avatars/ali_v2.jpg",
    "updated_at": "2026-03-10T00:00:00Z"
  }
}
```

---

## 4.4 Expert API

**Service:** User Service
**Base Path:** `/experts`

### GET /experts

Platformdaki uzmanları sektör, yetenek ve deneyim bazlı filtreleme ile listeler. Pagination desteklidir.

**Query Parameters:**

| Parametre | Tip | Zorunlu | Açıklama |
|-----------|-----|---------|----------|
| `skill` | String | Hayır | Yetenek filtresi (ör: `java`, `react`) |
| `industry` | String | Hayır | Sektör filtresi (ör: `fintech`) |
| `min_experience` | Integer | Hayır | Minimum deneyim yılı |
| `page` | Integer | Hayır | Sayfa numarası (default: `0`) |
| `size` | Integer | Hayır | Sayfa boyutu (default: `20`) |

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "content": [
      {
        "id": "660e8400-e29b-41d4-a716-446655440001",
        "user": {
          "first_name": "Mehmet",
          "last_name": "Kaya",
          "avatar_url": "..."
        },
        "title": "Senior Software Engineer",
        "current_company": "Google",
        "experience_years": 8,
        "rating": 4.85,
        "skills": ["Java", "Spring Boot", "System Design"],
        "industries": ["Fintech", "E-Commerce"]
      }
    ],
    "page": 0,
    "size": 20,
    "total_elements": 142,
    "total_pages": 8
  }
}
```

### GET /experts/{id}

Belirli bir uzmanın detaylı profil bilgilerini ve müsaitlik takvimini getirir.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "user": {
      "first_name": "Mehmet",
      "last_name": "Kaya",
      "avatar_url": "..."
    },
    "bio": "8 yıllık yazılım deneyimi. Google ve Amazon'da backend mühendisliği.",
    "title": "Senior Software Engineer",
    "current_company": "Google",
    "experience_years": 8,
    "rating": 4.85,
    "skills": ["Java", "Spring Boot", "System Design"],
    "industries": ["Fintech", "E-Commerce"],
    "availability_slots": [
      {
        "id": "770e8400-...",
        "start_time": "2026-03-12T10:00:00Z",
        "end_time": "2026-03-12T11:00:00Z",
        "is_booked": false
      }
    ]
  }
}
```

---

## 4.5 Booking API

**Service:** Booking Service
**Base Path:** `/bookings`

### POST /bookings

Adayın, uzmanın boş bir randevu slot'unu rezerve ederek booking oluşturması. Çifte rezervasyonu engellemek için Redis Distributed Lock mekanizması devrededir.

**Request Body:**
```json
{
  "expert_id": "660e8400-e29b-41d4-a716-446655440001",
  "slot_id": "770e8400-e29b-41d4-a716-446655440002"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "booking_id": "880e8400-e29b-41d4-a716-446655440003",
    "candidate_id": "550e8400-...",
    "expert_id": "660e8400-...",
    "slot_id": "770e8400-...",
    "status": "CONFIRMED",
    "scheduled_time": "2026-03-12T10:00:00Z",
    "created_at": "2026-03-10T00:00:00Z"
  }
}
```

**Error Response (409 Conflict):**
```json
{
  "success": false,
  "error": {
    "code": "BOOKING_SLOT_UNAVAILABLE",
    "message": "This time slot has already been booked by another candidate."
  }
}
```

### GET /bookings

Authenticated kullanıcının tüm randevularını listeler.

**Query Parameters:**

| Parametre | Tip | Zorunlu | Açıklama |
|-----------|-----|---------|----------|
| `status` | String | Hayır | Durum filtresi: `PENDING`, `CONFIRMED`, `COMPLETED`, `CANCELLED` |

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "booking_id": "880e8400-...",
      "expert": {
        "first_name": "Mehmet",
        "last_name": "Kaya",
        "title": "Senior Software Engineer"
      },
      "scheduled_time": "2026-03-12T10:00:00Z",
      "status": "CONFIRMED"
    }
  ]
}
```

### GET /bookings/{id}

Belirli bir randevunun detay bilgilerini döner.

### GET /availability/{expertId}

Uzmanın henüz rezerve edilmemiş açık takvim slot'larını döner.

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "770e8400-...",
      "start_time": "2026-03-12T10:00:00Z",
      "end_time": "2026-03-12T11:00:00Z",
      "is_booked": false
    },
    {
      "id": "770e8401-...",
      "start_time": "2026-03-12T14:00:00Z",
      "end_time": "2026-03-12T15:00:00Z",
      "is_booked": false
    }
  ]
}
```

---

## 4.6 Interview API

**Service:** Interview Service
**Base Path:** `/interviews`

### POST /interviews/{bookingId}/start

Randevu saati gelmiş olan oturumu başlatır. InterviewSession tablosuna kayıt oluşturur ve client'a WebRTC bağlantı bilgilerini döner.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "session_id": "990e8400-e29b-41d4-a716-446655440004",
    "booking_id": "880e8400-...",
    "room_url": "wss://media.internview.io/room/abc123",
    "webrtc_config": {
      "ice_servers": [
        { "urls": "stun:stun.internview.io:3478" },
        { "urls": "turn:turn.internview.io:3478", "username": "user", "credential": "pass" }
      ]
    },
    "status": "IN_PROGRESS",
    "started_at": "2026-03-12T10:00:00Z"
  }
}
```

### GET /interviews/{id}

Belirli bir mülakat oturumunun bilgilerini getirir.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "session_id": "990e8400-...",
    "booking_id": "880e8400-...",
    "status": "COMPLETED",
    "started_at": "2026-03-12T10:00:00Z",
    "ended_at": "2026-03-12T10:45:00Z",
    "duration_minutes": 45,
    "recorded_video_url": "https://s3.amazonaws.com/internview/recordings/abc123.webm"
  }
}
```

### GET /interviews/{id}/report

Mülakat tamamlandıktan sonra AI analiz raporunu getirir.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "session_id": "990e8400-...",
    "analysis": {
      "wpm": 142,
      "total_words": 2840,
      "duration_seconds": 2700,
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
    },
    "created_at": "2026-03-12T11:15:00Z"
  }
}
```

> **Not:** Tüm endpoint'lere gelen istekler API Gateway (Spring Cloud Gateway) üzerinden route edilmektedir. Gateway katmanında authentication filter, rate limiting ve request logging uygulanır.
