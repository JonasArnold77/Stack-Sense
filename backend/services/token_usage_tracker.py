"""
Verfolgt den Claude-Token-Verbrauch pro eingehendem Request.

`claude_service` ist ein Singleton, der von allen gleichzeitigen Requests
geteilt wird — der Verbrauch darf deshalb nicht als Attribut auf `self`
gezählt werden (das würde bei parallelen Requests race). Eine ContextVar
ist pro asyncio-Task isoliert, also pro Request sauber getrennt.
"""
from contextlib import asynccontextmanager
from contextvars import ContextVar

_usage_var: ContextVar[int] = ContextVar("claude_token_usage", default=0)


def record_usage(input_tokens: int, output_tokens: int) -> None:
    """Wird direkt nach jedem `client.messages.create(...)`-Call in
    claude_service aufgerufen."""
    _usage_var.set(_usage_var.get() + input_tokens + output_tokens)


@asynccontextmanager
async def track_usage():
    """Setzt den Zähler für die Dauer des Blocks zurück und gibt am Ende
    (über den mutable `holder`) den im Block verbrauchten Gesamtwert zurück."""
    token = _usage_var.set(0)
    holder = {"tokens": 0}
    try:
        yield holder
    finally:
        holder["tokens"] = _usage_var.get()
        _usage_var.reset(token)
