# Tech Stack

## 2.1 Overview

Internview'in teknoloji seçimleri üç temel prensibe dayanmaktadır:

1. **Production-Ready Olgunluk** — Endüstri standartlarında kanıtlanmış teknolojiler
2. **Ölçeklenebilirlik** — Artan kullanıcı yüküne yatay olarak adapte olabilme
3. **Geliştirici Verimliliği** — Hızlı prototipleme ve sürdürülebilir kod tabanı

| Katman | Teknoloji |
|--------|-----------|
| **Mobile Client** | Flutter + Riverpod |
| **Web Client** | Next.js + React |
| **Backend** | Java 21 + Spring Boot + Spring Cloud |
| **Database** | PostgreSQL |
| **Cache & Lock** | Redis |
| **Event Streaming** | Apache Kafka (KRaft Mode) |
| **Real-Time Video** | WebRTC + Mediasoup (SFU) + Coturn (STUN/TURN) |
| **AI & Speech** | Python + OpenAI Whisper |
| **Infrastructure** | AWS (EC2, S3, VPC) + Docker + GitHub Actions |

---

## 2.2 Frontend Technologies

### Flutter (Mobile Client)

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Tek kod tabanından iOS ve Android uygulaması üretir. Native performansa yakın UI render mekanizması sunar. |
| **Cross-Platform** | Single codebase ile iki platform desteği; geliştirme süresini yarıya indirir |
| **State Management** | Riverpod — ölçeklenebilir, test edilebilir ve reaktif state yönetimi |
| **WebRTC Desteği** | `flutter_webrtc` paketi ile native WebRTC entegrasyonu |
| **UI Geliştirme Hızı** | Hot Reload sayesinde anlında görsel geri bildirim |

### Next.js (Web Client)

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Server-Side Rendering (SSR) ve Static Site Generation (SSG) ile yüksek performanslı, SEO dostu web uygulaması sunar. |
| **React Ekosistemi** | Geniş bileşen kütüphanesi ve topluluk desteği |
| **SEO** | SSR/SSG sayesinde arama motorlarında indekslenebilir sayfalar |
| **WebRTC Entegrasyonu** | Tarayıcı içi native WebRTC API erişimi |
| **Performans** | Otomatik code splitting, image optimization, edge caching |

---

## 2.3 Backend Technologies

### Java 21 & Spring Boot

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Enterprise dünyasında en olgun mikroservis ekosistemi. JVM'in güvenilirliği ve Java 21'in modern özellikleri (Virtual Threads, Pattern Matching) bir arada. |
| **Microservice Support** | Spring Cloud Gateway, Consul (Service Discovery), Resilience4j (Circuit Breaker) |
| **Güvenlik** | Spring Security — JWT, OAuth2, role-based access control |
| **Virtual Threads** | Java 21 ile gelen sanal thread desteği; yüksek eşzamanlılıkta (concurrent) düşük kaynak tüketimi |
| **Ecosystem** | Spring Data JPA, Spring Kafka, Spring WebSocket — her ihtiyaç için hazır modül |

### Spring Cloud Gateway

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Tüm dış trafiği tek noktadan yöneten, reactive ve yüksek performanslı API Gateway. |
| **Özellikler** | Route tanımlama, rate limiting, request/response logging, authentication filter |

### HashiCorp Consul

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Dağıtık ortamda servislerin birbirini otomatik keşfetmesi (Service Discovery) ve sağlık kontrolü (Health Check). |

---

## 2.4 Data Technologies

### PostgreSQL

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | ACID uyumlu, güvenilir ilişkisel veritabanı. JSONB desteği ile yarı-yapısal veriler için de idealdir. |
| **Relational Consistency** | Foreign key, transaction, constraint desteği ile veri bütünlüğü |
| **JSONB Support** | AI analiz sonuçları gibi değişken şemalı (schema-less) verilerin verimli depolanması |
| **Scalability** | Read replica, connection pooling (HikariCP) desteği |

### Redis

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | In-memory veri yapısı sunucusu; caching, distributed lock ve session management için microsecond seviyesinde yanıt süresi sunar. |
| **Distributed Lock** | Booking Service'te çifte rezervasyonu önlemek için atomik lock mekanizması (`SET NX EX`) |
| **Caching** | Sık sorgulanan verilerin (uzman listesi, profil bilgileri) önbelleklenmesi |
| **Session/State** | WebRTC signaling state ve oda bilgilerinin hızlı erişimli depolanması |

---

## 2.5 Event Streaming

### Apache Kafka

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Yüksek hacimli, dayanıklı ve ölçeklenebilir event streaming platformu. Servisler arası sıkı bağımlılığı ortadan kaldırır. |
| **Event-Driven Architecture** | Producer/Consumer modeli ile servisler birbirinden bağımsız çalışır |
| **High Throughput** | Saniyede yüz binlerce mesaj işleyebilme kapasitesi |
| **Durability** | Mesajlar disk üzerine yazılır; tüketilmemiş eventler kaybolmaz |
| **Scalability** | Topic partition'ları ile paralel tüketim ve yatay ölçekleme |
| **KRaft Mode** | Kafka 3.3+ ile ZooKeeper bağımlılığı kaldırıldı; metadata yönetimi Kafka'nın kendi Raft consensus protokolü ile sağlanır |

---

## 2.6 Real-Time Communication

### WebRTC

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Tarayıcı ve mobil cihazlar arasında eklenti gerektirmeden düşük gecikmeli, peer-to-peer video/ses iletişimi sağlar. |
| **Low Latency** | UDP tabanlı medya iletimi ile <200ms gecikme |
| **P2P & SFU** | Doğrudan peer veya media server üzerinden bağlantı esnekliği |
| **Codec Support** | VP8/VP9/H.264 video ve Opus audio codec desteği |

### Mediasoup (SFU — Selective Forwarding Unit)

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Client'lar arasında mesh bağlantı yerine merkezi sunucu üzerinden selektif yönlendirme yapar. Bu sayede sunucu tarafında kayıt (recording) alınabilir ve bant genişliği adaptasyonu sağlanır. |
| **Server-Side Recording** | Mülakat videolarının S3'e kaydedilmesi için gerekli |
| **Bandwidth Adaptation** | Simulcast/SVC ile dinamik kalite ayarı |

### Coturn (STUN/TURN Server)

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | NAT arkasındaki ve kısıtlayıcı firewall'ların olduğu ağlardaki client'ların WebRTC bağlantısı kurabilmesini garantiler. |
| **STUN** | Public IP keşfi |
| **TURN** | NAT traversal mümkün olmadığında relay bağlantısı |

---

## 2.7 AI & Speech Analysis

### OpenAI Whisper

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Düşük hata oranı (WER) ile çoklu dil desteği sunan, açık kaynak speech-to-text modeli. |
| **Accuracy** | Endüstrinin en düşük Word Error Rate değerlerinden biri |
| **Multi-Language** | Türkçe ve İngilizce dahil geniş dil desteği |
| **Self-Hosted** | Verilerin dış servislere gitmeden kendi altyapımızda işlenmesi |

---

## 2.8 Infrastructure & DevOps

### Docker

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Her servisi izole container olarak paketler. "Bende çalışıyor" problemini ortadan kaldırır. |
| **Docker Compose** | Lokal geliştirmede tüm bağımlılıkların (DB, Redis, Kafka) tek komutla ayağa kaldırılması |
| **Image Standardization** | Servisler arasında tutarlı build ve runtime ortamı |

### AWS (Amazon Web Services)

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | Global ölçekli, güvenilir cloud altyapısı. |
| **EC2** | Servis container'larının çalıştırılması |
| **S3** | Video kayıtları ve statik dosya depolaması |
| **VPC + Security Groups** | Network izolasyonu ve erişim kontrolleri |

### GitHub Actions

| Kriter | Detay |
|--------|-------|
| **Neden Seçildi?** | GitHub ile entegre, yaml tabanlı CI/CD pipeline. |
| **CI** | Her PR'da otomatik build ve test çalıştırma |
| **CD** | Merge sonrası otomatik deployment süreci |
