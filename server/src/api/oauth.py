import os, requests
from fastapi import HTTPException, APIRouter, Depends

from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from src.database import get_db
from src.crud import read_spotify_user, read_specific_user, store_specific_user, store_token
from src.security import create_jwt_token, verify_token
from src.utils import generate_challenge_from_verifier

from src.schemas import User_Response, Spotify_Token_Request, Token_Response
from src.config import TOKEN_EXPIRATION, TOKEN_TYPE

from urllib.parse import urlencode
from dotenv import load_dotenv
load_dotenv()

SPOTIFY_CLIENT_ID = os.getenv("SPOTIFY_CLIENT_ID")
SPOTIFY_CLIENT_SECRET = os.getenv("SPOTIFY_CLIENT_SECRET")
APP_REDIRECT_URI = os.getenv("APP_REDIRECT_URI")

TOKEN_URL = "https://accounts.spotify.com/api/token"
PROFILE_URL = "https://api.spotify.com/v1/me"
SEARCH_URL = "https://api.spotify.com/v1/search"

router = APIRouter()

@router.post("/spotify/callback", response_model=Token_Response, status_code=200)
async def spotify_callback(data: Spotify_Token_Request, db: Session = Depends(get_db)):
  challenge = generate_challenge_from_verifier(data.code_verifier)
  print(f"[FASTAPI] Code: {data.code}")
  print(f"[FASTAPI] Code Verifier: {data.code_verifier}")
  print(f"[FASTAPI] Generated Challenge from verifier: {challenge}")

  payload = {
    "grant_type": "authorization_code",
    "code": data.code,
    "redirect_uri": APP_REDIRECT_URI,
    "client_id": SPOTIFY_CLIENT_ID,
    "code_verifier": data.code_verifier,
  }
  encoded_payload = urlencode(payload)
  print(f"[FASTAPI] Encoded Payload: {encoded_payload}")

  token_headers = { "Content-Type": "application/x-www-form-urlencoded" }

  token_response = requests.post(TOKEN_URL, data=encoded_payload, headers=token_headers, timeout=20)
  print(f"[FASTAPI] Token Response: {token_response}")

  if token_response.status_code != 200:
    token_response_error = token_response.json()
    raise HTTPException(status_code=500, detail=f"Token exchange failed: {token_response_error}")
  
  token_data = token_response.json()
  print(f"[FASTAPI] Token Data: {token_data}")
  access_token = token_data["access_token"]
  refresh_token = token_data["refresh_token"]
  expires_at = datetime.utcnow() + timedelta(seconds=token_data["expires_in"])
  
  if not access_token or not refresh_token:
    raise HTTPException(status_code=500, detail="Token exchange failed.")
  
  profile_headers = {"Authorization": f"Bearer {access_token}"}

  profile_response = requests.get(PROFILE_URL, headers=profile_headers, timeout=20)
  print(f"[FASTAPI] Profile Response: {profile_response}")

  if profile_response.status_code != 200:
    raise HTTPException(status_code=500, detail="Failed to get Spotify profile.")
  
  profile_data = profile_response.json()
  print(f"[FASTAPI] Profile Data: {profile_data}")
  spotify_id = profile_data.get("id")
  email = profile_data.get("email", "")
  username = profile_data.get("display_name", "")

  if not spotify_id:
    raise HTTPException(status_code=500, detail="Missing Spotify user ID.")
  
  user = read_spotify_user(db, spotify_id)
  if not user:
    user = store_specific_user(db, spotify_id, email, username)

    if not user:
      raise HTTPException(status_code=500, detail="User creation failed.")

  jwt_token = create_jwt_token(user)
  print(f"[FASTAPI] JWT TOKEN: {jwt_token}")
  store_token(db, user.user_id, access_token, TOKEN_TYPE["ACCESS_TOKEN"], expires_at)
  store_token(db, user.user_id, refresh_token, TOKEN_TYPE["REFRESH_TOKEN"], None)
  store_token(db, user.user_id, jwt_token, TOKEN_TYPE["JWT_TOKEN"], TOKEN_EXPIRATION)
  
  return { 'access_token': access_token, 'refresh_token': refresh_token, 'jwt_token': jwt_token }

@router.post("/user/read", response_model=User_Response, status_code=200)
async def user_read(token_payload = Depends(verify_token), db: Session = Depends(get_db)):
  user_id = token_payload.get('payload', {}).get('sub')
  user = read_specific_user(db, user_id)
  return user
