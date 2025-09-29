from fastapi import HTTPException
from sqlalchemy.orm import Session, selectinload
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import desc

from src.models import Token_Type, Genres, User, Album, Audio, Audio_Genres, Streams, Locations
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
def read_token_type(db: Session):
  return db.query(Token_Type).all()
  
@db_safe
def read_genres(db: Session):
  return db.query(Genres).all()
  
@db_safe
def read_specific_genre(db: Session, genre_name: str):
  return db.query(Genres).filter(Genres.genre_name == genre_name).first()

@db_safe
def read_genre_by_id(db: Session, genre_id: int):
  return db.query(Genres).filter(Genres.genre_id == genre_id).first()

@db_safe
def read_spotify_user(db: Session, spotify_id: int):
  return db.query(User).filter(User.spotify_id == spotify_id).first()
  
@db_safe
def read_local_user(db: Session, user_id: int):
  return db.query(User).filter(User.user_id == user_id).first()

@db_safe
def read_username(db: Session, username: str):
  return db.query(User).filter(User.username == username).first()

@db_safe 
def read_all_album(db: Session, user_id: int):
  return (db.query(Album).filter(Album.user_id == user_id).order_by(desc(Album.created_at)).all())

@db_safe
def read_specific_album(db: Session, user_id: int, album_id: int):
  return db.query(Album).filter(Album.user_id == user_id, Album.album_id == album_id).first()
  
@db_safe
def read_album_by_name(db: Session, user_id: int, album_name: str):
  return db.query(Album).filter(Album.user_id == user_id, Album.album_name == album_name).first()

@db_safe
def read_all_audio(db: Session, user_id: int):
  return (
    db.query(Audio)
    .options(
      selectinload(Audio.genre_links).selectinload(Audio_Genres.genre),
      selectinload(Audio.user),
      selectinload(Audio.album),
      selectinload(Audio.streams)
    )
    .filter(Audio.user_id == user_id)
    .order_by(desc(Audio.created_at))
    .all()
  )

@db_safe
def read_specific_audio(db: Session, user_id: int, audio_id: int):
  return db.query(Audio).options(
    selectinload(Audio.genre_links).selectinload(Audio_Genres.genre),
    selectinload(Audio.user),
    selectinload(Audio.album),
    selectinload(Audio.streams)).filter(Audio.user_id == user_id, Audio.audio_id == audio_id).first()
  
@db_safe
def read_audio_by_path_and_title(db: Session, user_id: int, audio_path: str, audio_title: str):
  return db.query(Audio).filter(
    Audio.user_id == user_id,
    Audio.audio_record == audio_path,
    Audio.audio_title == audio_title
  ).first()

@db_safe
def read_audio_album(db: Session, user_id: int, album_id: int):
  return (
    db.query(Audio)
    .options(
      selectinload(Audio.genre_links).selectinload(Audio_Genres.genre),
      selectinload(Audio.user),
      selectinload(Audio.album),
      selectinload(Audio.streams)
    )
    .filter(Audio.user_id == user_id, Audio.album_id == album_id)
    .order_by(desc(Audio.created_at))
    .all()
  )

@db_safe
def read_audio_by_genre(db: Session, genre_id: int):
  return (
    db.query(Audio)
    .options(
      selectinload(Audio.genre_links).selectinload(Audio_Genres.genre),
      selectinload(Audio.user),
      selectinload(Audio.album),
      selectinload(Audio.streams)
    )
    .filter(Audio.visibility == "public", Audio_Genres.genre_id == genre_id)
    .order_by(desc(Audio.created_at))
    .all()
  )

@db_safe
def read_local_audio_location(db: Session, location_id: int):
  return (
    db.query(Streams)
    .filter(Streams.location_id == location_id, Streams.type == "local")
    .order_by(desc(Streams.stream_count))
    .all()
  )

@db_safe
def read_spotify_audio_location(db: Session, location_id: int):
  return (
    db.query(Streams)
    .filter(Streams.location_id == location_id, Streams.type == "spotify")
    .order_by(desc(Streams.stream_count))
    .all()
  )

@db_safe
def read_location(db: Session, latitude: float, longitude: float, precision: int):
  norm_lat, norm_lon = normalize_coordinates(latitude, longitude, precision)
  return db.query(Locations).filter(Locations.latitude == norm_lat, Locations.longitude == norm_lon).first()

@db_safe
def read_bounding_location(db: Session, min_lat: float, max_lat: float, min_lon: float, max_lon: float):
  return (db.query(Locations).filter(
    Locations.latitude.between(min_lat, max_lat),
    Locations.longitude.between(min_lon, max_lon)).all())

@db_safe
def read_local_streams(db: Session):
  return (db.query(Streams).filter(Streams.type == "local").order_by(desc(Streams.stream_count)).limit(50).all())

@db_safe
def read_spotify_streams(db: Session):
  return (db.query(Streams).filter(Streams.type == "spotify").order_by(desc(Streams.stream_count)).limit(50).all())

@db_safe
def read_audio_search(db: Session, query: str):
  search_term = f"%{query}%"
  return (
    db.query(Audio)
    .join(Audio.genre_links)
    .filter(Audio.audio_title.ilike(search_term))
    .options(
      selectinload(Audio.genre_links).selectinload(Audio_Genres.genre),
      selectinload(Audio.user),
      selectinload(Audio.album),
      selectinload(Audio.streams),
    )
    .order_by(Audio.created_at.desc())
    .limit(10)
    .all()
  )
