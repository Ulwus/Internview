# Internview

## Proje Amacı
Internview, adayların ve uzmanların bir araya gelerek gerçek zamanlı, gerçeğe en yakın profesyonel mülakat deneyimini yaşayabilecekleri yenilikçi bir platformdur. Amacımız, adayları mülakatlara hazırlarken objektif metriklerle taranan (yapay zeka analizleri) konuşma performanslarını ölçmektir.

## Özellikler
- **Kimlik Doğrulama (Auth Service):** JWT tabanlı kayıt, giriş ve token yenileme; API Gateway üzerinden `/auth` rotaları; rol bazlı erişim (aday, uzman, yönetici).
- **Uzman Profili ve Müsaitlik Yönetimi:** Uzmanlar kendi müsaitlik saatlerini belirleyebilir ve yönetebilir.
- **Gerçek Zamanlı Mülakat:** WebRTC ve Mediasoup altyapısıyla güvenilir, kesintisiz video ve ses görüşme imkanı.
- **Yapay Zeka Destekli Analiz:** OpenAI Whisper kullanılarak konuşmalar metne dökülür; konuşma hızı, duraksama oranı, dolgu kelime kullanımı gibi metrikler detaylı olarak hesaplanır.
- **Çifte Rezervasyon (Double Booking) Engelleme:** Redis tabanlı distributed lock mekanizması ile aynı saate birden fazla randevu alınması kesin olarak engellenir.
- **Event-Driven Mimari:** Apache Kafka sayesinde servisler arası asenkron iletişim ve yüksek ölçeklenebilirlik sağlanır.

## Sistem Mimarisi Özeti
Sistem, gerçek dünya startup gereksinimlerini karşılamak üzere dağıtık mikroservis yaklaşımıyla tasarlanmıştır:
- **API Gateway (Spring Cloud)**
- **Auth Service, User Service, Booking Service, Interview Service (Spring Boot)**
- **AI Analysis Service (Audio Extraction & Speech-to-Text)**
- **Event Bus (Apache Kafka)**
- **Real-Time Video (WebRTC + Mediasoup + Coturn)**
- **Web Client (Next.js + React)**
- **Mobile Client (Flutter App + Riverpod)**

Detaylı mimari şemalar ve servis açıklamaları için [Sistem Mimarisi](docs/system-architecture.md) dokümanına göz atınız.

## Kullanılan Teknolojiler
- **Backend:** Java 21, Spring Boot, Spring Cloud Gateway, Spring Security + JWT (Auth Service), Flyway, HashiCorp Consul (Service Discovery)
- **Veritabanı ve Önbellek:** PostgreSQL (İlişkisel & JSONB veriler için), Redis (Cache & Locking)
- **Message Broker:** Apache Kafka (KRaft Mode)
- **Gerçek Zamanlı İletişim:** WebRTC, Mediasoup (SFU Server), Coturn (STUN/TURN)
- **Yapay Zeka:** OpenAI Whisper (Speech-to-Text), Veri Analizi
- **Web Uygulama:** Next.js, React, WebRTC
- **Mobil Uygulama:** Flutter, Riverpod (State Management), flutter_webrtc
- **Cloud ve Deployment:** Amazon Web Services (EC2, S3, VPC, Security Groups), Docker, GitHub Actions CI/CD

Detaylı seçim nedenleri için [Kullanılan Teknolojiler](docs/tech-stack.md) dokümanını okuyun.

## Dokümanlar
Projenin tüm teknik tasarım dokümanları `docs/` klasöründe yer almaktadır:

| Doküman | Açıklama |
|---------|----------|
| [System Architecture](docs/system-architecture.md) | High-level mimari, servis bileşenleri, veri akışı, ölçeklenebilirlik ve deployment genel bakış |
| [Tech Stack](docs/tech-stack.md) | Kullanılan teknolojiler, seçim kriterleri ve her bir teknolojinin gerekçesi |
| [Domain Model](docs/domain-model.md) | Core entity tanımları, alan tipleri, ilişki haritası ve ER diyagramı |
| [API Design](docs/api-design.md) | RESTful endpoint taslakları, request/response örnekleri ve hata formatları |
| [Event Architecture](docs/event-architecture.md) | Kafka tabanlı event-driven mimari, topic'ler, producer/consumer akışları |
| [WebRTC Flow](docs/webrtc-flow.md) | Video signaling akışı, SFU modeli, NAT traversal ve media flow detayları |
| [Development Roadmap](docs/roadmap.md) | 14 haftalık geliştirme planı, milestone'lar, haftalık görevler ve risk analizi |

## Setup Guide
Proje şu anda **Hafta 3 (API Gateway)**, **Hafta 4 (Auth Service)**, **Hafta 5 (User Service)** ve **Hafta 6 (Booking Service)** aşamalarını tamamlamış durumdadır. Gateway tarafında route tanımları, basic authentication filter, rate limiting ve loglama; auth tarafında Spring Security, HS256 JWT (üretim/doğrulama), Flyway ile PostgreSQL şeması, `register` / `login` / `refresh` uçları ve rol tabanlı erişim (RBAC); user tarafında ise `User`, `ExpertProfile`, `Skill`, `Industry` domain modeli, JPA Specification tabanlı filtreleme + pagination ile `GET /experts`, `GET /experts/{id}`, `GET /experts/me`, `PUT /experts/me`, `GET|PUT /users/profile`, `GET /industries`, `GET /skills` uçları; booking tarafında `AvailabilitySlot` ve `Booking` domain modeli, `GET /availability/{expertId}` (public), `POST|GET|DELETE /experts/me/availability`, `POST /bookings` (Redis distributed lock ile çift rezervasyon koruması), `GET /bookings/{id}`, `GET /bookings/me/candidate`, `GET /bookings/me/expert`, `PATCH /bookings/{id}/status` uçları ve booking durum makinesi (PENDING → CONFIRMED → COMPLETED/CANCELLED) ile birlikte servis/controller slice testleri bulunmaktadır. Geliştirme ortamı Docker Compose ile PostgreSQL, Redis, Kafka ve Consul servislerini tek komutla ayağa kaldıracak şekilde yapılandırılmıştır. Klasör iskeleti aşağıdaki gibidir:

```text
internview
  backend/           # Spring Boot mikroservisleri
    gateway/         # Spring Cloud Gateway (8080)
    auth-service/    # JWT kimlik doğrulama (8081)
    user-service/
    booking-service/
    interview-service/
  web/               # Next.js (Web Frontend) projesi
  mobile/            # Flutter (Mobil Client) projesi
  infrastructure/    # Kafka, DB, Mediasoup vs. yapılandırma dosyaları (Docker)
  docs/              # Sistem Tasarım ve Mimari Dokümanları
  README.md          # Proje Genel Kullanım Dokümanı (şu an okuduğunuz dosya)
```

### Hafta 2 – Docker Altyapısı

Hafta 2 kapsamında lokal geliştirme ortamı için temel altyapı bileşenleri Docker Compose ile ayağa kaldırılır:

- **PostgreSQL** (veritabanı)
- **Redis** (cache & distributed lock)
- **Kafka (KRaft Mode)** (event bus)
- **Consul** (service discovery – ileride Spring Cloud ile entegre edilecek)

#### 1. Ortam Değişkenleri

Kök dizinde örnek bir env dosyası bulunur:

- `.env.example` → örnek değerler
- `.env` → gerçek lokal değerler (git tarafından izlenmez)

Temel değişkenler:

- `COMPOSE_PROJECT_NAME=internview`
- `DOCKER_NETWORK=internview-net`
- `POSTGRES_DB=internview`
- `POSTGRES_USER=internview`
- `POSTGRES_PASSWORD=internview_password`
- `KAFKA_CLUSTER_ID=abcdefghijklmnopqrstuv`

İlk kurulum için:

```bash
cp .env.example .env
```

Gerekiyorsa `.env` içindeki şifre vb. değerleri değiştirebilirsiniz.

#### 2. Docker Compose ile altyapıyı ayağa kaldırma

`infrastructure/docker-compose.yml` dosyası aşağıdaki servisleri içerir:

- `postgres` → 5432
- `redis` → 6379
- `kafka` → 9092
- `consul` → 8500

Çalıştırmak için:

```bash
cd infrastructure
docker compose up -d
```

Tüm containerlar aynı Docker ağı üzerinde çalışır (`internview-net`), böylece backend servisleri şu host/port kombinasyonlarını kullanabilir:

- PostgreSQL: `jdbc:postgresql://postgres:5432/internview`
- Redis: `redis://redis:6379`
- Kafka: `kafka:9092`
- Consul: `http://consul:8500`

#### 3. Hızlı health / bağlantı kontrolleri

Altyapı ayağa kalktıktan sonra temel kontroller:

- **PostgreSQL**
  - Host makineden:
    ```bash
    psql "postgresql://internview:internview_password@localhost:5432/internview"
    ```
- **Redis**
  - Host makineden veya container içinden ping:
    ```bash
    redis-cli -h localhost -p 6379 PING
    # veya
    docker exec -it internview-redis redis-cli PING
    ```
- **Kafka**
  - Container içinden basit topic oluşturma / listeleme:
    ```bash
    docker exec -it internview-kafka kafka-topics.sh \
      --bootstrap-server kafka:9092 \
      --create --topic internview_ping --partitions 1 --replication-factor 1

    docker exec -it internview-kafka kafka-topics.sh \
      --bootstrap-server kafka:9092 --list
    ```
- **Consul**
  - Tarayıcıdan UI:
    ```text
    http://localhost:8500/ui/
    ```
  - CLI ile lider health kontrolü:
    ```bash
    curl http://localhost:8500/v1/status/leader
    ```

#### 4. Spring Boot servislerinden bağlantı (lokal JVM)

Spring Boot servislerini şimdilik IDE’den lokal JVM olarak çalıştırırken:

- DB URL (lokal port üzerinden):
  - `spring.datasource.url=jdbc:postgresql://localhost:5432/${POSTGRES_DB}`
- Redis:
  - `spring.data.redis.host=localhost`
  - `spring.data.redis.port=6379`
- Kafka:
  - `spring.kafka.bootstrap-servers=localhost:9092`

 Container içinden çalıştırmak istediğinizde host isimlerini `postgres`, `redis`, `kafka`, `consul` olarak değiştirebilirsiniz.

#### 5. Auth Service (Hafta 4)

Auth Service varsayılan olarak **8081** portunda çalışır. API Gateway (`8080`) üzerinden **`/auth/*`** ile erişilir; gateway **`StripPrefix=1`** kullandığı için servis içi path’ler `/register`, `/login`, `/refresh` şeklindedir (prefix yok). Detaylı sözleşme için [API Design – Authentication](docs/api-design.md) bölümüne bakın.

**Önkoşullar:** PostgreSQL ayakta olmalıdır (Flyway migration’lar ilk açılışta şemayı oluşturur). `backend/auth-service/src/main/resources/application.properties` içindeki `POSTGRES_*` ve `auth.jwt.*` değerleri ihtiyaca göre override edilebilir.

**Ortam değişkenleri (özet):**

| Değişken | Açıklama |
|----------|----------|
| `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | Veritabanı bağlantısı |
| `AUTH_JWT_SECRET` | HS256 için yeterince uzun gizli anahtar (üretimde zorunlu önerilir) |
| `AUTH_ACCESS_TOKEN_TTL_SECONDS` | Access token ömrü (varsayılan 3600) |
| `AUTH_REFRESH_TOKEN_TTL_SECONDS` | Refresh token ömrü |

**Çalıştırma (lokal JVM, Java 21):**

```bash
cd backend/auth-service
./mvnw spring-boot:run
```

**Örnek istekler (gateway açıkken):**

```bash
# Kayıt
curl -s -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"aday@example.com","password":"SecurePass123!","first_name":"Ali","last_name":"Yılmaz","role":"CANDIDATE"}'

# Giriş
curl -s -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"aday@example.com","password":"SecurePass123!"}'
```

Korumalı örnek uçlar (doğrudan auth servisine, Bearer token ile): `GET http://localhost:8081/me`, `GET http://localhost:8081/admin/ping` (yalnızca `ADMIN` rolü).

**Testler:** `cd backend/auth-service && ./mvnw test` — CI ortamında Docker yoksa `test` profili H2 bellek veritabanı kullanır; gerçek PostgreSQL + Flyway akışı için altyapıyı Docker ile ayağa kaldırıp servisi `default` profille çalıştırın.

