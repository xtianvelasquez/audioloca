from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from datetime import datetime

from src.models import Emotions, Token_Type, Token, User, Album, Audio_Type, Audio

def emotion_initializer(db: Session):
  emotions = ['angry', 'disgust', 'fear', 'happy', 'sad', 'surprise', 'neutral']
  emotion_to_add = []
  
  for emotion in emotions:
    existing_emotion = db.query(Emotions).filter_by(emotion_label=emotion).first()
    if not existing_emotion:
      emotion_to_add.append(Emotions(emotion_label=emotion))

  if emotion_to_add:
    db.bulk_save_objects(emotion_to_add)
    db.commit()

def token_type_initializer(db: Session):
  types = ['access_token', 'refresh_token', 'jwt_token']
  type_to_add = []
  
  for type in types:
    existing_type = db.query(Token_Type).filter_by(type_name=type).first()
    if not existing_type:
      type_to_add.append(Token_Type(type_name=type))

  if type_to_add:
    db.bulk_save_objects(type_to_add)
    db.commit()

def audio_type_initializer(db: Session):
  types = ['song', 'speech', 'podcast', 'audiobook', 'spoken_poetry', 'convo']
  type_to_add = []
  
  for type in types:
    existing_type = db.query(Audio_Type).filter_by(type_name=type).first()
    if not existing_type:
      type_to_add.append(Audio_Type(type_name=type))

  if type_to_add:
    db.bulk_save_objects(type_to_add)
    db.commit()

def store_token(db: Session, user_id: int, token_hash: str, token_type_id: int, expires_at: int):
  try:
    new_token = Token(
    user_id=user_id,
    token_hash=token_hash,
    token_type_id=token_type_id,
    is_active=True,
    issued_at=datetime.utcnow().replace(second=0, microsecond=0),
    expires_at=expires_at,
    )

    db.add(new_token)
    db.commit()
    db.refresh(new_token)

    return new_token
  
  except SQLAlchemyError as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')

def store_specific_user(db: Session, spotify_id: int, email: str, username: str):
  try:
    new_user = User(
      spotify_id=spotify_id,
      email=email,
      username=username,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user
  
  except SQLAlchemyError as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')

def store_album(
    db: Session,
    user_id: int,
    album_cover_path: str,
    album_name: str,
    description: str
  ):
  try:
    new_album = Album(
      user_id=user_id,
      album_cover=album_cover_path,
      album_name=album_name,
      description=description
    )
    db.add(new_album)
    db.commit()
    db.refresh(new_album)

    return new_album

  except SQLAlchemyError as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')

def store_audio(
    db: Session,
    user_id: int,
    audio_type_id: int,
    album_id: int,
    emotion_id: int,
    visibility: str,
    audio_photo_path: str,
    audio_record_path: str,
    audio_title: str,
    description: str,
    duration: int
  ):
  try:
    new_audio = Audio(
      user_id=user_id,
      audio_type_id=audio_type_id,
      album_id=album_id,
      emotion_id=emotion_id,
      visibility=visibility,
      audio_photo=audio_photo_path,
      audio_record=audio_record_path,
      audio_title=audio_title,
      description=description,
      duration=duration
    )
    db.add(new_audio)
    db.commit()
    db.refresh(new_audio)

    return new_audio

  except SQLAlchemyError as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f'Unexpected error: {str(e)}')
