from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import desc

from src.models import Emotions, Token_Type, User, Album, Audio_Type, Audio

def read_all_emotion(db: Session):
  try:
    return db.query(Emotions).all()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')

  except Exception as e:
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')
  
def read_token_type(db: Session):
  try:
    return db.query(Token_Type).all()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')

  except Exception as e:
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')
  
def read_audio_type(db: Session):
  try:
    return db.query(Audio_Type).all()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')

  except Exception as e:
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')

def read_spotify_user(db: Session, spotify_id: int):
  try:
    return db.query(User).filter(User.spotify_id == spotify_id).first()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')

  except Exception as e:
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')
  
def read_specific_user(db: Session, user_id: int):
  try:
    return db.query(User).filter(User.user_id == user_id).first()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')

  except Exception as e:
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')
  
def read_all_album(db: Session, user_id: int):
  try:
    return (db.query(Album).filter(Album.user_id == user_id).order_by(desc(Album.created_at)).all())

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')

  except Exception as e:
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')

def read_specific_album(db: Session, user_id: int, album_id: int):
  try:
    return db.query(Album).filter(Album.user_id == user_id, Album.album_id == album_id).first()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')

  except Exception as e:
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')

def read_all_audio(db: Session, user_id: int):
  try:
    return (db.query(Audio).filter(Audio.user_id == user_id).order_by(desc(Audio.created_at)).all())

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')

  except Exception as e:
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')

def read_specific_audio(db: Session, user_id: int, audio_id: int):
  try:
    return db.query(Audio).filter(Audio.user_id == user_id, Audio.audio_id == audio_id).first()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')

  except Exception as e:
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')

def read_audio_album(db: Session, user_id: int, album_id: int):
  try:
    return (db.query(Audio).filter(Audio.user_id == user_id, Audio.album_id == album_id).order_by(desc(Audio.created_at)).all())

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')

  except Exception as e:
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')
