"""
Migration: Fügt 'source' Spalte zur supplement_facts Tabelle hinzu.
Einmalig ausführen bevor populate_efsa.py oder populate_nih_ods.py laufen.

    python scripts/migrate_add_source.py
"""
import psycopg2

DB_CONFIG = {
    "host": "stacksense-db.chym26e8iw2p.eu-central-1.rds.amazonaws.com",
    "user": "stacksense",
    "password": "Jo790097",
    "dbname": "postgres",
    "port": 5432,
    "sslmode": "require",
}

conn = psycopg2.connect(**DB_CONFIG)
conn.autocommit = True
cur = conn.cursor()

print("Füge 'source' Spalte zu supplement_facts hinzu...")
cur.execute("""
    ALTER TABLE supplement_facts
    ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'manual';
""")

print("Füge 'source' Spalte zu studies hinzu...")
cur.execute("""
    ALTER TABLE studies
    ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'pubmed';
""")

# Index für schnelle Filterung nach Quelle
cur.execute("""
    CREATE INDEX IF NOT EXISTS facts_source_idx ON supplement_facts(source);
""")
cur.execute("""
    CREATE INDEX IF NOT EXISTS studies_source_idx ON studies(source);
""")

cur.close()
conn.close()
print("✅ Migration erfolgreich!")
