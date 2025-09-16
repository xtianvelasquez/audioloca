from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.dialects.postgresql import insert
from typing import Optional

from datetime import datetime

from src.models import Genres, Token_Type, Token, User, Album, Audio, Locations, Streams
from src.utils import normalize_coordinates

def token_type_initializer(db: Session):
  types = ["access_token", "refresh_token", "jwt_token"]
  type_to_add = []
  
  for type in types:
    existing_type = db.query(Token_Type).filter_by(type_name=type).first()
    if not existing_type:
      type_to_add.append(Token_Type(type_name=type))

  if type_to_add:
    db.bulk_save_objects(type_to_add)
    db.commit()

def genre_initializer(db: Session):
  genres = [
    "pop", "hip-hop/rap", "rock", "jazz/blues", "classical", "folk/acoustic", "latin/world", "ambient/chill", "metal", "experimental", "country", "electronic"
  ]

  genre_to_add = []

  for genre in genres:
    existing_genre = db.query(Genres).filter_by(genre_name=genre).first()
    if not existing_genre:
      genre_to_add.append(Genres(genre_name=genre))

  if genre_to_add:
    db.bulk_save_objects(genre_to_add)
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
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def store_specific_user(db: Session, spotify_id: int, email: str, username: str, password: str):
  try:
    new_user = User(
      spotify_id=spotify_id,
      email=email,
      username=username,
      password=password,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user
  
  except SQLAlchemyError as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

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
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def store_audio(
    db: Session,
    user_id: int,
    genre_id: int,
    album_id: int,
    visibility: str,
    audio_record_path: str,
    audio_title: str,
    description: str,
    duration: int
  ):
  try:
    new_audio = Audio(
      user_id=user_id,
      genre_id=genre_id,
      album_id=album_id,
      visibility=visibility,
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
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")
  
def store_location(db: Session, latitude: float, longitude: float):
  try:
    norm_lat, norm_lon = normalize_coordinates(latitude, longitude, 3)
    new_location = Locations(latitude=norm_lat, longitude=norm_lon)
    db.add(new_location)
    db.commit()
    db.refresh(new_location)

    return new_location

  except SQLAlchemyError as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def store_stream(db: Session, user_id: int, location_id: int, audio_id: Optional[int], spotify_id: Optional[str], type: str):
  try:
    stmt = insert(Streams).values(
      user_id=user_id,
      location_id=location_id,
      audio_id=audio_id,
      spotify_id=spotify_id,
      type=type,
      stream_count=1,
      last_played=datetime.utcnow().replace(second=0, microsecond=0)
    )
    
    stmt = stmt.on_conflict_do_update(
      constraint="uq_user_audio",
      set_={
        "stream_count": Streams.stream_count + 1,
        "last_played": datetime.utcnow().replace(second=0, microsecond=0),
      },
    )

    db.execute(stmt)
    db.commit()
    return stmt
      
  except SQLAlchemyError as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
  
  except Exception as e:
    db.rollback()
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")
