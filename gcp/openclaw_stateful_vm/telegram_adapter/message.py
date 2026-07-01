"""Fake message envelopes for the non-enabled Telegram adapter skeleton."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class InboundMessage:
    """Minimal fake inbound message shape used by tests and future adapters."""

    chat_id: str
    text: str

    @classmethod
    def from_values(cls, chat_id: str | int, text: str | None) -> "InboundMessage":
        return cls(chat_id=str(chat_id), text=text or "")


@dataclass(frozen=True)
class OutboundMessage:
    """Telegram-safe response envelope without Telegram API coupling."""

    chat_id: str
    text: str
    authorized: bool
    command: str | None
