from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import desc

from src.models import Token_Type, Genres, User, Album, Audio, Streams, Locations
from src.utils import normalize_coordinates
  
def read_token_type(db: Session):
  try:
    return db.query(Token_Type).all()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")
  
def read_genres(db: Session):
  try:
    return db.query(Genres).all()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_spotify_user(db: Session, spotify_id: int):
  try:
    return db.query(User).filter(User.spotify_id == spotify_id).first()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")
  
def read_local_user(db: Session, user_id: int):
  try:
    return db.query(User).filter(User.user_id == user_id).first()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_username(db: Session, username: str):
  try:
    return db.query(User).filter(User.username == username).first()
  
  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")
  
def read_all_album(db: Session, user_id: int):
  try:
    return (db.query(Album).filter(Album.user_id == user_id).order_by(desc(Album.created_at)).all())

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_specific_album(db: Session, user_id: int, album_id: int):
  try:
    return db.query(Album).filter(Album.user_id == user_id, Album.album_id == album_id).first()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_all_audio(db: Session, user_id: int):
  try:
    return (db.query(Audio).filter(Audio.user_id == user_id).order_by(desc(Audio.created_at)).all())

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_specific_audio(db: Session, user_id: int, audio_id: int):
  try:
    return db.query(Audio).filter(Audio.user_id == user_id, Audio.audio_id == audio_id).first()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_audio_album(db: Session, user_id: int, album_id: int):
  try:
    return (db.query(Audio).filter(Audio.user_id == user_id, Audio.album_id == album_id).order_by(desc(Audio.created_at)).all())

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_audio_genre(db: Session, genre_id: int):
  try:
    return (db.query(Audio).filter(Audio.visibility == "public", Audio.genre_id == genre_id).order_by(desc(Audio.created_at)).all())

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_local_audio_location(db: Session, location_id: int):
  try:
    return (
      db.query(Streams)
      .filter(Streams.location_id == location_id, Streams.type == "local")
      .order_by(desc(Streams.stream_count))
      .all()
    )
  
  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")
  
def read_spotify_audio_location(db: Session, location_id: int):
  try:
    return (
      db.query(Streams)
      .filter(Streams.location_id == location_id, Streams.type == "spotify")
      .order_by(desc(Streams.stream_count))
      .all()
    )
  
  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_location(db: Session, latitude: float, longitude: float, precision: int):
  try:
    norm_lat, norm_lon = normalize_coordinates(latitude, longitude, precision)
    return db.query(Locations).filter(Locations.latitude == norm_lat, Locations.longitude == norm_lon).first()

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_local_streams(db: Session):
  try:
    return (db.query(Streams).filter(Streams.type == "local").order_by(desc(Streams.stream_count)).limit(50).all())

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

def read_spotify_streams(db: Session):
  try:
    return (db.query(Streams).filter(Streams.type == "spotify").order_by(desc(Streams.stream_count)).limit(50).all())

  except SQLAlchemyError as e:
    raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

  except Exception as e:
    raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")
