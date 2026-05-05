# ── Build Stage ─────────────────────────────────────────
# Mediasoup C++ native bağımlılıklarını derlemek için gerekli araçlar
FROM node:20-bookworm-slim AS builder

RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .

# ── Production Stage ───────────────────────────────────
FROM node:20-bookworm-slim

# FFmpeg — recording pipeline için gerekli
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src

# Recording çıktı dizini
RUN mkdir -p /tmp/internview-recordings

EXPOSE 3000
EXPOSE 40000-40099/udp

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1)).on('error', () => process.exit(1))"

CMD ["node", "src/server.js"]
