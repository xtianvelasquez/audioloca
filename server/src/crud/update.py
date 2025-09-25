from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from datetime import datetime

from src.models import Token

def logout_token(db: Session, token: str):
  try:
    stored_token = db.query(Token).filter(Token.token_hash == token).first()
    
    if not stored_token:
      raise HTTPException(status_code=404, detail='Token not found.')
    
    stored_token.is_active=False
    stored_token.revoked_at=datetime.utcnow().replace(second=0, microsecond=0)
    db.commit()
    db.refresh(stored_token)

    return {'message': 'You have been logged out.'}
  
  except SQLAlchemyError as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')
  