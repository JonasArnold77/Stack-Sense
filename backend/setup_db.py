"""
Einmalig ausführen: richtet pgvector + Schema in der AWS RDS DB ein.
"""
import psycopg2

DB_HOST = "stacksense-db.chym26e8iw2p.eu-central-1.rds.amazonaws.com"
DB_USER = "stacksense"
DB_PASS = "Jo790097"
DB_NAME = "postgres"

print("Verbinde mit RDS...")
conn = psycopg2.connect(
    host=DB_HOST, user=DB_USER, password=DB_PASS,
    dbname=DB_NAME, port=5432, sslmode="require"
)
conn.autocommit = True
cur = conn.cursor()

print("Aktiviere pgvector...")
cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")

print("Erstelle Tabellen...")
cur.execute("""
CREATE TABLE IF NOT EXISTS supplements (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    slug        TEXT UNIQUE NOT NULL,
    category    TEXT,
    created_at  TIMESTAMP DEFAULT NOW()
);
""")

cur.execute("""
CREATE TABLE IF NOT EXISTS studies (
    id              SERIAL PRIMARY KEY,
    supplement_slug TEXT NOT NULL REFERENCES supplements(slug),
    pmid            TEXT UNIQUE,
    title           TEXT NOT NULL,
    abstract        TEXT,
    year            INT,
    evidence_level  TEXT CHECK (evidence_level IN ('green','yellow','red')),
    embedding       vector(384),
    created_at      TIMESTAMP DEFAULT NOW()
);
""")

cur.execute("""
CREATE TABLE IF NOT EXISTS supplement_facts (
    id              SERIAL PRIMARY KEY,
    supplement_slug TEXT NOT NULL REFERENCES supplements(slug),
    fact_type       TEXT NOT NULL,
    content         TEXT NOT NULL,
    embedding       vector(384),
    created_at      TIMESTAMP DEFAULT NOW()
);
""")

cur.execute("""
CREATE INDEX IF NOT EXISTS studies_embedding_idx
    ON studies USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 50);
""")

cur.execute("""
CREATE INDEX IF NOT EXISTS facts_embedding_idx
    ON supplement_facts USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 50);
""")

cur.close()
conn.close()
print("✅ Schema erfolgreich angelegt!")
