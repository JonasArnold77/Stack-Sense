# ---- Build Stage ----
FROM python:3.11-slim AS builder

WORKDIR /app

# Nur requirements kopieren — Layer-Caching nutzen
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Runtime Stage ----
FROM python:3.11-slim

WORKDIR /app

# Installierte Pakete aus Builder übernehmen
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# App-Code kopieren
COPY . .

# Port 8080 (AWS App Runner Standard)
EXPOSE 8080

# Produktions-Start: 1 Worker reicht für MVP, kein --reload
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]
