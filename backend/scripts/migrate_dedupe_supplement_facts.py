"""
Einmalige Migration: supplement_facts enthielt bisher keinen Unique-Constraint
auf (supplement_slug, source, content) — dadurch hat "ON CONFLICT DO NOTHING"
in den populate_*.py-Skripten nie gegriffen (id ist immer neu), und mehrfache
Skript-Läufe haben denselben Fakt wiederholt eingefügt (93 von 321 Zeilen waren
Duplikate, Stand 2026-08-23).

1. Entfernt bestehende Duplikate (behält jeweils die Zeile mit der kleinsten id).
2. Legt einen Unique-Index auf (supplement_slug, source, content) an, damit
   künftige "ON CONFLICT DO NOTHING"-Inserts wirklich greifen.

Ausführen (aus dem backend/ Ordner):
    python scripts/migrate_dedupe_supplement_facts.py
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


def main():
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = False
    cur = conn.cursor()

    cur.execute("SELECT COUNT(*) FROM supplement_facts")
    before = cur.fetchone()[0]

    cur.execute("""
        DELETE FROM supplement_facts
        WHERE id NOT IN (
            SELECT MIN(id) FROM supplement_facts
            GROUP BY supplement_slug, source, content
        )
    """)
    deleted = cur.rowcount

    # md5(content) statt raw content im Index — content kann mehrere hundert
    # Zeichen lang sein, ein Btree-Index auf dem vollen Text könnte bei künftig
    # längeren Fakten das Zeilengrößen-Limit von Postgres-Indizes reißen.
    cur.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS supplement_facts_dedup_idx
        ON supplement_facts (supplement_slug, source, md5(content))
    """)

    conn.commit()

    cur.execute("SELECT COUNT(*) FROM supplement_facts")
    after = cur.fetchone()[0]

    cur.close()
    conn.close()

    print(f"Vorher: {before} Zeilen | Gelöscht: {deleted} Duplikate | Nachher: {after} Zeilen")
    print("Unique-Index supplement_facts_dedup_idx angelegt.")


if __name__ == "__main__":
    main()
