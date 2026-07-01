"""Safe diagnostic events for adapter tests and future local validation."""

from __future__ import annotations

from dataclasses import dataclass

from gcp.openclaw_stateful_vm.telegram_adapter.commands import normalize_command
from gcp.openclaw_stateful_vm.telegram_adapter.defaults import SUPPORTED_COMMANDS
from gcp.openclaw_stateful_vm.telegram_adapter.message import InboundMessage


@dataclass(frozen=True)
class AdapterDiagnosticEvent:
    """Non-secret event shape that avoids raw chat IDs and message text."""

    event: str
    command: str
    authorized: bool
    supported: bool


def safe_diagnostic_event(
    message: InboundMessage,
    allowed_chat_ids: frozenset[str],
) -> AdapterDiagnosticEvent:
    command = normalize_command(message.text)
    authorized = message.chat_id in allowed_chat_ids
    return AdapterDiagnosticEvent(
        event="telegram_adapter_message",
        command=command,
        authorized=authorized,
        supported=command in SUPPORTED_COMMANDS,
    )
