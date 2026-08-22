"""
Migration: Legt die Tabellen für vorberechnete Empfehlungen an.
Einmalig ausführen bevor scripts/precompute_recommendations.py läuft.

    python scripts/migrate_add_precompute_tables.py
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

print("Lege 'precomputed_goal_ranking' an...")
cur.execute("""
    CREATE TABLE IF NOT EXISTS precomputed_goal_ranking (
        goal TEXT NOT NULL,
        db_only BOOLEAN NOT NULL,
        supplement_id TEXT NOT NULL,
        name TEXT NOT NULL,
        base_relevance_score INT NOT NULL,
        generated_at TIMESTAMP DEFAULT now(),
        PRIMARY KEY (goal, db_only, supplement_id)
    );
""")

print("Lege 'precomputed_supplement_info' an...")
cur.execute("""
    CREATE TABLE IF NOT EXISTS precomputed_supplement_info (
        supplement_id TEXT NOT NULL,
        db_only BOOLEAN NOT NULL,
        simple_explanation TEXT,
        food_sources JSONB,
        dosage TEXT,
        intake_time TEXT,
        intake_hint TEXT,
        generated_at TIMESTAMP DEFAULT now(),
        PRIMARY KEY (supplement_id, db_only)
    );
""")

cur.execute("""
    CREATE INDEX IF NOT EXISTS goal_ranking_goal_idx
    ON precomputed_goal_ranking(goal, db_only);
""")

cur.close()
conn.close()
print("✅ Migration erfolgreich!")
