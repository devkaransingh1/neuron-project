from fastapi import APIRouter, Request, HTTPException, Depends, Header
from app.core.firebase import verify_firebase_token
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
import requests

from app.db.session import get_db
from app.models.user import User
from app.core.config import FRONTEND_URL

from app.integrations.google.oauth import (
    get_google_authorization_url,
    create_google_flow,
)


router = APIRouter()


# ============================================================
# CURRENT USER
# ============================================================

def get_current_user(
    request: Request,
    db: Session = Depends(get_db),
    authorization: str = Header(default=None)
):
    # Firebase authentication
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split(" ", 1)[1]

        try:
            decoded_token = verify_firebase_token(token)
        except Exception:
            raise HTTPException(
                status_code=401,
                detail="Invalid Firebase token"
            )

        firebase_uid = decoded_token.get("uid")
        email = decoded_token.get("email")

        if not firebase_uid or not email:
            raise HTTPException(
                status_code=401,
                detail="Firebase account details missing"
            )

        user = db.query(User).filter(User.email == email).first()

        if not user:
            user = User(
                google_id=firebase_uid,
                name=decoded_token.get("name") or email.split("@")[0],
                email=email,
                picture_url=decoded_token.get("picture")
            )
            db.add(user)
            db.commit()
            db.refresh(user)

        return user

    # Existing session authentication
    user_id = request.session.get("user_id")

    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user


# ============================================================
# GOOGLE LOGIN
# ============================================================

@router.get("/google/login")
def google_login(
    request: Request,
    db: Session = Depends(get_db),
):

    user_id = request.session.get("user_id")

    # Already logged in
    if user_id:
        user = db.query(User).filter(
            User.id == user_id
        ).first()

        if user:
            return RedirectResponse(
                url=f"{FRONTEND_URL}/chat"
            )

        request.session.clear()

    authorization_url, state = get_google_authorization_url()

    request.session["oauth_state"] = state

    return RedirectResponse(
        url=authorization_url
    )


# ============================================================
# GOOGLE CALLBACK
# ============================================================

@router.get("/google/callback")
def google_callback(
    request: Request,
    db: Session = Depends(get_db)
):
    code = request.query_params.get("code")

    if not code:
        raise HTTPException(
            status_code=400,
            detail="Google authorization code missing"
        )

    flow = create_google_flow()

    flow.fetch_token(
        code=code
    )

    credentials = flow.credentials

    response = requests.get(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        headers={
            "Authorization": f"Bearer {credentials.token}"
        }
    )

    if response.status_code != 200:
        raise HTTPException(
            status_code=400,
            detail="Failed to fetch Google user information"
        )

    user_info = response.json()

    # --------------------------------------------------------
    # CHECK IF USER ALREADY EXISTS
    # --------------------------------------------------------

    user = db.query(User).filter(
        User.google_id == user_info["id"]
    ).first()

    if user:

        request.session["user_id"] = user.id

        return RedirectResponse(
            url=f"{FRONTEND_URL}/chat"
        )

    # --------------------------------------------------------
    # CREATE NEW USER
    # --------------------------------------------------------

    user = User(
        google_id=user_info["id"],
        name=user_info["name"],
        email=user_info["email"],
        picture_url=user_info.get("picture")
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    request.session["user_id"] = user.id

    return RedirectResponse(
        url=f"{FRONTEND_URL}/chat"
    )


# ============================================================
# CURRENT USER PROFILE
# ============================================================

@router.get("/me")
def me(
    request: Request,
    user=Depends(get_current_user)
):
    print("SESSION:", request.session)

    return {
        "message": "profile accessed",
        "name": user.name,
        "email": user.email,
        "picture_url": user.picture_url
    }


# ============================================================
# LOGOUT
# ============================================================

@router.get("/logout")
def logout(request: Request):

    request.session.clear()

    return {
        "message": "user logged out successfully"
    }
