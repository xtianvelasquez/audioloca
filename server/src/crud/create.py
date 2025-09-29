from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.dialects.postgresql import insert
from typing import Optional
import logging

from datetime import datetime

from src.models import Genres, Token_Type, Token, User, Album, Audio, Audio_Genres, Locations, Streams
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
    "pop",
    "hip-hop/rap",
    "rock",
    "jazz/blues",
    "classical",
    "folk/acoustic",
    "latin/world",
    "ambient/chill",
    "metal",
    "experimental",
    "country",
    "electronic"
  ]

  genre_to_add = []

  for genre in genres:
    existing_genre = db.query(Genres).filter_by(genre_name=genre).first()
    if not existing_genre:
      genre_to_add.append(Genres(genre_name=genre))

  if genre_to_add:
    db.bulk_save_objects(genre_to_add)
    db.commit()

@db_safe
def store_token(db: Session, user_id: int, token_hash: str, token_type_id: int, expires_at: int):
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

@db_safe
def store_specific_user(db: Session, spotify_id: int, email: str, username: str, password: str):
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

@db_safe
def store_album(
    db: Session,
    user_id: int,
    album_cover_path: str,
    album_name: str
  ):
  new_album = Album(
    user_id=user_id,
    album_cover=album_cover_path,
    album_name=album_name
  )
  db.add(new_album)
  db.commit()
  db.refresh(new_album)

  return new_album

@db_safe
def store_audio(
    db: Session,
    user_id: int,
    album_id: int,
    visibility: str,
    audio_record_path: str,
    audio_title: str,
    duration: int
  ):
  new_audio = Audio(
    user_id=user_id,
    album_id=album_id,
    visibility=visibility,
    audio_record=audio_record_path,
    audio_title=audio_title,
    duration=duration
    )
  db.add(new_audio)
  db.commit()
  db.refresh(new_audio)

  return new_audio

@db_safe
def link_audio_to_genre(db: Session, audio_id: int, genre_id: int):
  existing_link = db.query(Audio_Genres).filter_by(
      audio_id=audio_id,
      genre_id=genre_id
  ).first()

  if existing_link is None:
    new_link = Audio_Genres(
      audio_id=audio_id,
      genre_id=genre_id
    )
    db.add(new_link)
    db.commit()
    db.refresh(new_link)
    return new_link
    
  return existing_link
  
@db_safe
def store_location(db: Session, latitude: float, longitude: float):
  norm_lat, norm_lon = normalize_coordinates(latitude, longitude, 6)
  new_location = Locations(latitude=norm_lat, longitude=norm_lon)
  db.add(new_location)
  db.commit()
  db.refresh(new_location)

  return new_location

@db_safe
def store_stream(db: Session, user_id: int, location_id: int, audio_id: Optional[int], spotify_id: Optional[str], type: str):
  now = datetime.utcnow().replace(second=0, microsecond=0)
  if audio_id and spotify_id:
    raise HTTPException(status_code=400, detail="Provide either audio_id or spotify_id, not both.")
  if not audio_id and not spotify_id:
    raise HTTPException(status_code=400, detail="Either audio_id or spotify_id must be provided.")

  conflict_constraint = "uq_user_audio" if audio_id else "uq_user_spotify"
  stmt = insert(Streams).values(
    user_id=user_id,
    location_id=location_id,
    audio_id=audio_id,
    spotify_id=spotify_id,
    type=type,
    stream_count=1,
    last_played=now
  ).on_conflict_do_update(
    constraint=conflict_constraint,
    set_={
      "stream_count": Streams.stream_count + 1,
      "last_played": now,
    }
  )
  db.execute(stmt)
  db.flush()
  db.commit()
  
  action = "updated" if db.query(Streams).filter_by(user_id=user_id, audio_id=audio_id, spotify_id=spotify_id).first() else "inserted"
  return {"status": action}

def store_mock_stream(
  db: Session,
  user_id: int,
  location_id: int,
  audio_id: Optional[int],
  spotify_id: Optional[str],
  type: str,
  stream_count: int
):
  now = datetime.utcnow().replace(second=0, microsecond=0)
  conflict_constraint = "uq_user_audio" if audio_id else "uq_user_spotify"

  stmt = insert(Streams.__table__).values(
    user_id=user_id,
    location_id=location_id,
    audio_id=audio_id,
    spotify_id=spotify_id,
    type=type,
    stream_count=stream_count,
    last_played=now
  ).on_conflict_do_update(
    constraint=conflict_constraint,
    set_={
      "stream_count": stream_count,
      "last_played": now
    }
  )

  db.execute(stmt)
  db.commit()
