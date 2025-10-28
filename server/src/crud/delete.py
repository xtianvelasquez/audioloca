from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.dialects.postgresql import insert

from src.models import Album, Audio
from src.utils import normalize_coordinates

def db_safe(fn):
  def wrapper(*args, **kwargs):
    db = args[0]
    try:
      return fn(*args, **kwargs)
    except SQLAlchemyError as e:
      db.rollback()
      raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
      db.rollback()
      raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")
  return wrapper

@db_safe
def delete_specific_album(db: Session, user_id: int, album_id: int):
  album = db.query(Album).filter_by(user_id=user_id, album_id=album_id).first()

  if not album:
    raise HTTPException(status_code=404, detail="Album not found.")

  db.query(Audio).filter_by(album_id=album_id).delete()

  db.delete(album)
  db.commit()
  return True
