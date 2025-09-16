import os, jwt
from fastapi import HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
import re, bcrypt

from sqlalchemy.orm import Session

from src.database import get_db
from src.models import Token
from src.config import TOKEN_EXPIRATION

from dotenv import load_dotenv
load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")
Oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def create_jwt_token(user):
  payload = {
    "sub": str(user.user_id),
    "user": user.username,
    "exp": TOKEN_EXPIRATION
  }

  return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

def decode_token(token: str):
  try:
    return jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
  
  except jwt.ExpiredSignatureError:
    raise HTTPException(status_code=401, detail="Token has expired.")
  
  except jwt.DecodeError:
    raise HTTPException(status_code=401, detail="Invalid signature.")
  
  except jwt.InvalidTokenError:
    raise HTTPException(status_code=401, detail="Invalid token.")

def verify_token(db: Session = Depends(get_db), raw_token: str = Depends(Oauth2_scheme)):
  try:
    payload = decode_token(raw_token)
    user_id: int = payload.get("sub")

    if user_id is None:
      raise HTTPException(status_code=401, detail="Invalid token.")

    stored_token = db.query(Token).filter(Token.token_hash == raw_token, Token.is_active == True, Token.user_id == user_id).first()

    if not stored_token:
      raise HTTPException(status_code=401, detail="Token not found or revoked.")

    return {"raw": raw_token, "payload": payload}

  except Exception as e:
    raise HTTPException(status_code=500, detail="Unexpected error.")

def validate_password(password: str):
  pattern = r"^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{6,}$"
  return bool(re.match(pattern, password))

def hash_password(password: str):
  return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(plain_password: str, hashed_password: str):
  return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
