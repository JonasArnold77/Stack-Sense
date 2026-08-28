"""
Gemeinsame Hilfsfunktion zum Extrahieren von JSON aus Claude-Antworten —
Claude umschließt JSON gelegentlich mit ```json ... ``` Codeblöcken oder
zusätzlichem Fließtext davor/danach. Genutzt von claude_service.py und
recipe_service.py, um Duplizierung der Extraktions-Regex zu vermeiden.
"""
import re


def extract_json(raw: str) -> str:
    code_block_match = re.search(r"```(?:json)?\s*(\{.*\}|\[.*\])\s*```", raw, re.DOTALL)
    if code_block_match:
        return code_block_match.group(1).strip()
    json_match = re.search(r"\{.*\}|\[.*\]", raw, re.DOTALL)
    if json_match:
        return json_match.group(0).strip()
    return raw
