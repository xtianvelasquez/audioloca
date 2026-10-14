from types import SimpleNamespace
import logging
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
def delete_specific_album(db: Session, user_id: int, album_id: int):
  album = db.query(Album).filter_by(user_id=user_id, album_id=album_id).first()

  if not album:
    raise HTTPException(status_code=404, detail="Album not found.")

  album_cover = album.album_cover
  db.query(Audio).filter_by(album_id=album_id).delete()

  db.delete(album)
  db.commit()
  return SimpleNamespace(album_cover=album_cover)

@db_safe
def delete_specific_audio(db: Session, user_id: int, audio_id: int):
  audio = db.query(Audio).filter_by(user_id=user_id, audio_id=audio_id).first()

  if not audio:
    raise HTTPException(status_code=404, detail="Audio not found.")
  
  audio_record = audio.audio_record
  db.delete(audio)
  db.commit()
  return SimpleNamespace(audio_record=audio_record)
