
from fastapi import APIRouter, Request, Depends, HTTPException, BackgroundTasks
from app.services.gmail_sync import run_initial_gmail_sync
from sqlalchemy.orm import Session
from fastapi.responses import RedirectResponse

import base64
import html
import re

from bs4 import BeautifulSoup

from app.db.session import get_db
from app.models.user import User
from app.api.v1.auth import get_current_user

from app.integrations.google.oauth import (
    create_gmail_flow,
    create_gmail_service,
)


router = APIRouter()


# ============================================================
# GMAIL OAUTH
# ============================================================

@router.get("/connect/gmail")
def connect_gmail(
    request: Request,
    user=Depends(get_current_user)
):
    if user.is_gmail_connected:
        return {
            "message": "gmail is already connected",
            "connected": True
        }

    flow = create_gmail_flow()

    authorization_url, state = flow.authorization_url(
        access_type="offline",
        prompt="consent",
        login_hint=user.email,
    )

    request.session["gmail_oauth_state"] = state

    return RedirectResponse(
        url=authorization_url
    )




@router.get("/connect/gmail/callback")
def gmail_callback(
    request: Request,
    background_tasks: BackgroundTasks,
    user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    code = request.query_params.get("code")

    if not code:
        raise HTTPException(
            status_code=400,
            detail="gmail connection Authorization code missing"
        )

    flow = create_gmail_flow()

    flow.fetch_token(code=code)

    # --------------------------------------------------------
    # SAVE GMAIL OAUTH CREDENTIALS
    # --------------------------------------------------------

    user.gmail_access_token = flow.credentials.token

    # Google may not return a refresh token on every
    # subsequent authorization. Never overwrite an existing
    # refresh token with None.
    if flow.credentials.refresh_token:
        user.gmail_refresh_token = flow.credentials.refresh_token

    user.gmail_token_expiry = flow.credentials.expiry
    user.is_gmail_connected = True

    # Initial sync has not completed yet.
    user.gmail_initial_sync_completed = False
    user.gmail_sync_status = "syncing"

    db.add(user)
    db.commit()
    db.refresh(user)

    # --------------------------------------------------------
    # START RAG SYNC IN BACKGROUND
    # --------------------------------------------------------

    background_tasks.add_task(
        run_initial_gmail_sync,
        user.id
    )

    # --------------------------------------------------------
    # REDIRECT TO CHAT IMMEDIATELY
    # --------------------------------------------------------

    return RedirectResponse(
        url="https://neuron-71tk.onrender.com/chat"
    )




# ============================================================
# EMAIL BODY DECODING
# ============================================================

def decode_email_body(data: str) -> str:
    decoded = base64.urlsafe_b64decode(data)
    return decoded.decode(
        "utf-8",
        errors="replace"
    )


def find_body_parts(
    part,
    plain_parts,
    html_parts
):
    mime_type = part.get(
        "mimeType",
        ""
    )

    body = part.get(
        "body",
        {}
    )

    data = body.get("data")

    if data and mime_type == "text/plain":
        plain_parts.append(
            decode_email_body(data)
        )

    elif data and mime_type == "text/html":
        html_parts.append(
            decode_email_body(data)
        )

    for child in part.get(
        "parts",
        []
    ):
        find_body_parts(
            child,
            plain_parts,
            html_parts
        )


# ============================================================
# HTML CLEANING
# ============================================================

def clean_html_body(raw_html: str) -> str:

    # Gmail/email content can contain escaped HTML.
    raw_html = raw_html.replace(
        "\\u003C",
        "<"
    )

    raw_html = raw_html.replace(
        "\\u003E",
        ">"
    )

    raw_html = raw_html.replace(
        "\\u0026",
        "&"
    )

    # Decode HTML entities.
    raw_html = html.unescape(
        raw_html
    )

    # Remove conditional comments.
    raw_html = re.sub(
        r"<!--\s*\[if.*?<!\s*\[endif\]\s*-->",
        "",
        raw_html,
        flags=re.IGNORECASE | re.DOTALL
    )

    # Remove remaining comments.
    raw_html = re.sub(
        r"<!--.*?-->",
        "",
        raw_html,
        flags=re.DOTALL
    )

    soup = BeautifulSoup(
        raw_html,
        "html.parser"
    )

    # Remove email-client/template elements.
    for tag in soup.find_all([
        "style",
        "script",
        "head",
        "title",
        "svg",
        "noscript"
    ]):
        tag.decompose()

    text = soup.get_text(
        " ",
        strip=True
    )

    text = html.unescape(
        text
    )

    # Remove spaces before punctuation.
    text = re.sub(
        r"\s+([,.!?;:])",
        r"\1",
        text
    )

    # Normalize spaces.
    text = re.sub(
        r"[ \t]+",
        " ",
        text
    )

    return text.strip()


# ============================================================
# DUPLICATE BLOCK CLEANING
# ============================================================

def remove_duplicate_blocks(text: str) -> str:

    lines = text.splitlines()

    result = []
    seen = set()

    for line in lines:

        normalized = line.strip().lower()

        if not normalized:
            continue

        if normalized in seen:
            continue

        seen.add(normalized)

        result.append(line)

    return "\n".join(result)


# ============================================================
# FULL EMAIL BODY EXTRACTION
# ============================================================

def extract_email_body(payload) -> str:

    html_parts = []
    plain_parts = []

    def walk(part):

        mime_type = part.get(
            "mimeType",
            ""
        )

        body = part.get(
            "body",
            {}
        )

        data = body.get(
            "data"
        )

        if data:

            decoded = decode_email_body(
                data
            )

            if mime_type == "text/html":

                html_parts.append(
                    decoded
                )

            elif mime_type == "text/plain":

                plain_parts.append(
                    decoded
                )

        for child in part.get(
            "parts",
            []
        ):
            walk(child)

    walk(payload)

    # Prefer HTML because many emails have
    # poorly formatted plain-text versions.
    if html_parts:

        cleaned_parts = []

        for part in html_parts:

            cleaned = clean_html_body(
                part
            )

            if cleaned:
                cleaned_parts.append(
                    cleaned
                )

        return "\n".join(
            cleaned_parts
        )

    if plain_parts:

        return "\n".join(
            plain_parts
        ).strip()

    return ""


# ============================================================
# GMAIL MESSAGE LIST
# ============================================================

@router.get("/gmail/messages")
def gmail_messages(
    user=Depends(get_current_user)
):

    if not user.is_gmail_connected:
        raise HTTPException(
            status_code=401,
            detail="gmail access not granted"
        )

    service = create_gmail_service(user)

    results = service.users().messages().list(
        userId="me",
        maxResults=10
    ).execute()

    messages = results.get(
        "messages",
        []
    )

    emails = []

    for message in messages:

        data = service.users().messages().get(
            userId="me",
            id=message["id"],
            format="metadata",
            metadataHeaders=[
                "From",
                "Subject",
                "Date"
            ]
        ).execute()

        headers = data.get(
            "payload",
            {}
        ).get(
            "headers",
            []
        )

        email = {
            "id": message["id"],
            "from": "",
            "subject": "",
            "date": "",
            "body": data.get(
                "snippet",
                ""
            )
        }

        for header in headers:

            name = header["name"].lower()
            value = header["value"]

            if name == "from":
                email["from"] = value

            elif name == "subject":
                email["subject"] = value

            elif name == "date":
                email["date"] = value

        emails.append(
            email
        )

    return {
        "count": len(emails),
        "emails": emails
    }


# ============================================================
# GET SINGLE FULL GMAIL MESSAGE
# ============================================================


@router.get("/gmail/messages/{message_id}")
def gmail_message(
    message_id: str,
    user=Depends(get_current_user)
):

    if not user.is_gmail_connected:
        raise HTTPException(
            status_code=401,
            detail="gmail access not granted"
        )

    return get_gmail_message(
        user=user,
        message_id=message_id
    )



# ============================================================
# INTERNAL GMAIL SEARCH HELPER
# ============================================================

def search_gmail_messages(
    user,
    query: str = "",
    max_results: int = 10
):
    """
    Search the authenticated user's Gmail inbox.

    This function is used by both the HTTP API and
    the Neuron live Gmail tool.

    Important:
    - Gmail API performs the actual search.
    - Metadata is requested instead of the full email body.
    - Results are sorted newest → oldest using internalDate.
    """

    if not user.is_gmail_connected:
        raise HTTPException(
            status_code=401,
            detail="gmail access not granted"
        )

    service = create_gmail_service(user)

    # Safety limit.
    max_results = max(
        1,
        min(
            max_results,
            100
        )
    )

    results = service.users().messages().list(
        userId="me",
        q=query,
        maxResults=max_results
    ).execute()

    messages = results.get(
        "messages",
        []
    )

    emails = []

    for message in messages:

        data = service.users().messages().get(
            userId="me",
            id=message["id"],
            format="metadata",
            metadataHeaders=[
                "From",
                "To",
                "Subject",
                "Date"
            ]
        ).execute()

        payload = data.get(
            "payload",
            {}
        )

        headers = payload.get(
            "headers",
            []
        )

        email = {
            "id": data.get(
                "id",
                message["id"]
            ),
            "thread_id": data.get(
                "threadId",
                ""
            ),
            "sender": "",
            "recipient": "",
            "subject": "",
            "date": "",
            "snippet": data.get(
                "snippet",
                ""
            ),
            # Used internally for chronological sorting.
            "internal_date": int(
                data.get(
                    "internalDate",
                    0
                )
            )
        }

        for header in headers:

            name = header.get(
                "name",
                ""
            ).lower()

            value = header.get(
                "value",
                ""
            )

            if name == "from":

                email["sender"] = value

            elif name == "to":

                email["recipient"] = value

            elif name == "subject":

                email["subject"] = value

            elif name == "date":

                email["date"] = value

        emails.append(
            email
        )

    # Gmail normally returns results in a useful order,
    # but explicitly sort so Neuron always has deterministic
    # newest → oldest behavior.
    emails.sort(
        key=lambda email: email["internal_date"],
        reverse=True
    )

    return emails


# ============================================================
# GMAIL SEARCH HTTP ENDPOINT
# ============================================================

@router.get("/gmail/search")
def search_gmail(
    q: str = "",
    max_results: int = 10,
    user=Depends(get_current_user)
):

    emails = search_gmail_messages(
        user=user,
        query=q,
        max_results=max_results
    )

    # Do not expose internal sorting metadata
    # to the API/frontend.
    clean_emails = []

    for email in emails:

        clean_emails.append({
            "id": email["id"],
            "thread_id": email["thread_id"],
            "sender": email["sender"],
            "recipient": email["recipient"],
            "subject": email["subject"],
            "date": email["date"],
            "snippet": email["snippet"]
        })

    return {
        "count": len(clean_emails),
        "emails": clean_emails
    }
    
    
@router.get("/gmail/sync-status")
def gmail_sync_status(
    user=Depends(get_current_user)
):
    return {
        "connected": user.is_gmail_connected,
        "sync_status": user.gmail_sync_status,
        "sync_completed": user.gmail_initial_sync_completed
    }


def get_gmail_message(
    user,
    message_id: str
):
    """
    Fetch the complete Gmail message for a user.

    This is reusable by both:
    - the FastAPI Gmail message endpoint
    - the LangChain Gmail message tool
    """

    service = create_gmail_service(user)

    data = service.users().messages().get(
        userId="me",
        id=message_id,
        format="full"
    ).execute()

    headers = data.get(
        "payload",
        {}
    ).get(
        "headers",
        []
    )

    email = {
        "id": data["id"],
        "thread_id": data.get(
            "threadId",
            ""
        ),
        "from": "",
        "to": "",
        "subject": "",
        "date": "",
        "body": ""
    }

    for header in headers:

        name = header["name"].lower()
        value = header["value"]

        if name == "from":
            email["from"] = value

        elif name == "to":
            email["to"] = value

        elif name == "subject":
            email["subject"] = value

        elif name == "date":
            email["date"] = value

    email["body"] = extract_email_body(
        data["payload"]
    )

    return email


