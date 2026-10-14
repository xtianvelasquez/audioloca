from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from datetime import datetime

from src.models import Token

import logging

def db_safe(fn):
  def wrapper(*args, **kwargs):
    db = args[0]
    try:
      return fn(*args, **kwargs)
    except HTTPException:
      raise
    except SQLAlchemyError as e:
      if hasattr(db, "rollback"):
        db.rollback()
      logging.error(f"Database error in {fn.__name__}: {e}")
      raise HTTPException(status_code=500, detail="A database error occurred. Please try again.")
    except Exception as e:
      if hasattr(db, "rollback"):
        db.rollback()
      logging.error(f"Unexpected error in {fn.__name__}: {e}")
      raise HTTPException(status_code=500, detail="An unexpected error occurred. Please try again.")
  return wrapper

@db_safe
def logout_token(db: Session, token: str):
  stored_token = db.query(Token).filter(Token.token_hash == token).first()
    
  if not stored_token:
    raise HTTPException(status_code=404, detail='Token not found.')
    
  stored_token.is_active=False
  stored_token.revoked_at=datetime.utcnow().replace(second=0, microsecond=0)
  db.commit()
  db.refresh(stored_token)

  return {'message': 'You have been logged out.'}
