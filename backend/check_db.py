import psycopg2

conn = psycopg2.connect(
    host="stacksense-db.chym26e8iw2p.eu-central-1.rds.amazonaws.com",
    port=5432, dbname="postgres", user="stacksense",
    password="Jo790097", sslmode="require"
)
cur = conn.cursor()

cur.execute("SELECT source, COUNT(*) FROM supplement_facts GROUP BY source ORDER BY count DESC")
print("\n=== supplement_facts nach Quelle ===")
for r in cur.fetchall():
    print(f"  {r[0]}: {r[1]} Eintraege")

cur.execute("SELECT COUNT(*) FROM studies")
print(f"\n=== studies (PubMed): {cur.fetchone()[0]} Eintraege ===")

cur.execute("SELECT slug FROM supplements ORDER BY slug")
print("\n=== supplements ===")
for r in cur.fetchall():
    print(f"  {r[0]}")

conn.close()
