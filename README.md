# Internview

## Proje Amacı
Internview, adayların ve uzmanların bir araya gelerek gerçek zamanlı, gerçeğe en yakın profesyonel mülakat deneyimini yaşayabilecekleri yenilikçi bir platformdur. Amacımız, adayları mülakatlara hazırlarken objektif metriklerle taranan (yapay zeka analizleri) konuşma performanslarını ölçmektir.

## Özellikler
- **Kimlik Doğrulama:** JWT tabanlı kayıt, giriş, token yenileme ve rol bazlı erişim kontrolü (RBAC).
- **Uzman Eşleme & Randevu:** Sektör ve yetenek bazlı uzman filtreleme, müsaitlik yönetimi ve Redis distributed lock ile çifte rezervasyon engelleme.
- **Gerçek Zamanlı Mülakat:** WebRTC + Mediasoup (SFU) + Coturn (STUN/TURN) altyapısıyla kesintisiz video görüşme.
- **Yapay Zeka Analizi:** OpenAI Whisper ile konuşma metne dökülür; konuşma hızı, duraksama, dolgu kelime metrikleri hesaplanır.
- **Event-Driven Mimari:** Apache Kafka ile servisler arası asenkron iletişim.

## Sistem Mimarisi

```text
Client Layer          Backend Layer              Real-Time Layer         Data Layer
├── Web (Next.js)     ├── API Gateway (8080)     ├── Signaling (WS)      ├── PostgreSQL
└── Mobile (Flutter)  ├── Auth Service (8081)    ├── Mediasoup (SFU)     ├── Redis
                      ├── User Service (8082)    └── Coturn (STUN/TURN)  ├── Apache Kafka
                      ├── Interview Service(8083)                        └── AWS S3
                      ├── Booking Service (8084)
                      └── AI Analysis (Python)
```

Detaylı mimari → [System Architecture](docs/system-architecture.md)

## Kullanılan Teknolojiler

| Katman | Teknoloji |
|--------|-----------|
| **Backend** | Java 21, Spring Boot 4, Spring Cloud Gateway, Spring Security + JWT, Flyway |
| **Veritabanı** | PostgreSQL, Redis |
| **Event Streaming** | Apache Kafka (KRaft Mode) |
| **Gerçek Zamanlı** | WebRTC, Mediasoup (SFU), Coturn (STUN/TURN) |
| **Yapay Zeka** | Python, OpenAI Whisper |
| **Web** | Next.js, React |
| **Mobil** | Flutter, Riverpod |
| **Altyapı** | Docker, AWS (EC2, S3, VPC), GitHub Actions CI/CD |

Detaylı seçim nedenleri → [Tech Stack](docs/tech-stack.md)

## Proje Yapısı

```text
internview/
├── backend/
│   ├── gateway/              # API Gateway (8080)
│   ├── auth-service/         # JWT kimlik doğrulama (8081)
│   ├── user-service/         # Kullanıcı & uzman profilleri (8082)
│   ├── interview-service/    # Mülakat oturumu & signaling (8083)
│   ├── booking-service/      # Randevu yönetimi (8084)
│   ├── ai-analysis-service/  # Konuşma analizi (Python)
│   └── common-lib/           # Ortak kütüphane
├── web/                      # Next.js frontend
├── mobile/                   # Flutter mobil uygulama
├── infrastructure/           # Docker Compose, Coturn, Kafka config
│   ├── docker-compose.yml
│   ├── coturn/               # TURN/STUN yapılandırması
│   ├── postgres/
│   ├── redis/
│   ├── kafka/
│   └── scripts/
└── docs/                     # Teknik dokümanlar
```

## Hızlı Başlangıç

### 1. Ortam değişkenlerini oluştur

```bash
cp .env.example .env
```

### 2. Tüm sistemi ayağa kaldır

```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml up -d
```

Bu tek komut altyapı (PostgreSQL, Redis, Kafka, Consul, Coturn) ve tüm backend servislerini (Gateway, Auth, User, Booking, Interview) birlikte başlatır.
Mediasoup, görüşmeye katılan client'ın bağlandığı host'u transport oluştururken otomatik kullanır; local geliştirmede IP değiştikçe `.env` güncellemen gerekmez.

### 3. Testleri çalıştır

```bash
cd backend/auth-service && ./mvnw test
cd backend/interview-service && ./mvnw test
```

## Dokümanlar

| Doküman | Açıklama |
|---------|----------|
| [System Architecture](docs/system-architecture.md) | Mimari, servis bileşenleri, veri akışı |
| [Tech Stack](docs/tech-stack.md) | Teknoloji seçimleri ve gerekçeleri |
| [Domain Model](docs/domain-model.md) | Entity tanımları, ilişki haritası, ER diyagramı |
| [API Design](docs/api-design.md) | RESTful endpoint'ler, request/response örnekleri |
| [Event Architecture](docs/event-architecture.md) | Kafka topic'leri, producer/consumer akışları |
| [WebRTC Flow](docs/webrtc-flow.md) | Signaling, SFU modeli, NAT traversal |
| [Development Roadmap](docs/roadmap.md) | 14 haftalık geliştirme planı ve risk analizi |

## Geliştirme Durumu

Proje 14 haftalık bir geliştirme planı izlemektedir. Güncel ilerleme için [Development Roadmap](docs/roadmap.md) dokümanına bakınız.

| İş Paketi | Hafta | Durum |
|-----------|-------|-------|
| İP-1: Temel Altyapı | 1–2 | ✅ Tamamlandı |
| İP-2: Backend Servisleri | 3–6 | ✅ Tamamlandı |
| İP-3: Kafka Event Sistemi | 7 | ✅ Tamamlandı |
| İP-4: WebRTC Video Altyapısı | 8–10 | 🔄 Devam ediyor |
| İP-5: AI Konuşma Analizi | 11–12 | ⏳ Planlandı |
| İP-6: Önyüz & Canlıya Alma | 13–14 | ⏳ Planlandı |
