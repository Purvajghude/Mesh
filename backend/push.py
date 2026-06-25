"""
FCM push sender (HTTP v1).

Reads a user's device tokens and sends a notification via the Firebase Cloud
Messaging v1 API, authenticated with the service-account credentials in the
FIREBASE_SERVICE_ACCOUNT env var. google-auth is imported lazily so the rest of
the app imports fine even where it isn't installed.
"""

from __future__ import annotations

import json
import os
from typing import Any

import httpx
from supabase import Client

_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_creds = None
_project_id: str | None = None


def _credentials():
    """Cached service-account credentials + project id."""
    global _creds, _project_id
    if _creds is None:
        raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT")
        if not raw:
            raise RuntimeError("FIREBASE_SERVICE_ACCOUNT not set")
        info = json.loads(raw)
        _project_id = info["project_id"]
        from google.oauth2 import service_account  # lazy

        _creds = service_account.Credentials.from_service_account_info(
            info, scopes=[_SCOPE]
        )
    return _creds, _project_id


def _access_token() -> str:
    creds, _ = _credentials()
    if not creds.valid:
        from google.auth.transport.requests import Request  # lazy

        creds.refresh(Request())
    return creds.token


def send_to_user(
    db: Client,
    user_id: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Send a notification to every device the user has registered. Prunes
    tokens FCM reports as invalid."""
    rows = (
        db.table("device_tokens")
        .select("token")
        .eq("profile_id", user_id)
        .execute()
        .data
        or []
    )
    if not rows:
        return {"sent": 0, "tokens": 0}

    _, project_id = _credentials()
    bearer = _access_token()
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {"Authorization": f"Bearer {bearer}", "Content-Type": "application/json"}

    sent = 0
    with httpx.Client(timeout=10) as client:
        for r in rows:
            payload = {
                "message": {
                    "token": r["token"],
                    "notification": {"title": title, "body": body},
                    "data": {k: str(v) for k, v in (data or {}).items()},
                }
            }
            resp = client.post(url, headers=headers, json=payload)
            if resp.status_code == 200:
                sent += 1
            elif resp.status_code in (400, 403, 404):
                # Unregistered / invalid token → drop it.
                db.table("device_tokens").delete().eq("token", r["token"]).execute()
    return {"sent": sent, "tokens": len(rows)}
