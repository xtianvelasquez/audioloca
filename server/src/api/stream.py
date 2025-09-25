from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from src.database import get_db
from src.security import verify_token
from src.crud import read_local_audio_location, read_spotify_audio_location, read_location, store_location, store_stream, read_local_streams, read_spotify_streams
from src.schemas import Locations_Base, Streams_Create, Local_Streams_Response, Spotify_Streams_Response
from typing import List
import logging

router = APIRouter()

@router.post("/audioloca/audio/stream", status_code=201)
async def send_stream(data: Streams_Create, token_payload=Depends(verify_token), db: Session = Depends(get_db)):
  logging.info(f"Incoming stream data: {data.dict()}")
  user_id = token_payload.get("payload", {}).get("sub")

  location = read_location(db, data.latitude, data.longitude, 3)
  if location is None:
    location = store_location(db, data.latitude, data.longitude)

  if data.type == "local":
    store_stream(db, user_id, location.location_id, data.audio_id, None, data.type)
  else:
    store_stream(db, user_id, location.location_id, None, data.spotify_id, data.type)

  return {"message": "Stream recorded successfully."}

@router.post("/audioloca/audio/location", response_model=List[Local_Streams_Response], status_code=200)
async def audio_location_local(data: Locations_Base, db: Session = Depends(get_db)):
  for precision in [3, 2, 1]:
    location = read_location(db, data.latitude, data.longitude, precision)

    if location:
      streams = read_local_audio_location(db, location.location_id)
      if streams:
        return [
          Local_Streams_Response(
            audio_id=int(stream.audio.audio_id),
            username=stream.audio.user.username,
            album_cover=stream.audio.album.album_cover,
            stream_count=stream.stream_count,
            album_id=stream.audio.album_id,
            audio_record=stream.audio.audio_record,
            audio_title=stream.audio.audio_title,
            duration=stream.audio.duration,
            type=stream.type
          )

          for stream in streams if stream.audio.visibility == "public"
        ]

  streams = read_local_streams(db)
  return [
    Local_Streams_Response(
      audio_id=int(stream.audio.audio_id),
      username=stream.audio.user.username,
      album_cover=stream.audio.album.album_cover,
      stream_count=stream.stream_count,
      album_id=stream.audio.album_id,
      audio_record=stream.audio.audio_record,
      audio_title=stream.audio.audio_title,
      duration=stream.audio.duration,
      type=stream.type
    )
    
    for stream in streams if stream.audio.visibility == "public"
  ]

@router.get("/spotify/audio/location", response_model=List[Spotify_Streams_Response], status_code=200)
async def audio_location_spotify(data: Locations_Base, db: Session = Depends(get_db)):
  for precision in [3, 2, 1]:
    location = read_location(db, data.latitude, data.longitude, precision)

    if location:
      streams = read_spotify_audio_location(db, location.location_id)
      if streams:
        return [
          Spotify_Streams_Response(
            spotify_id=stream.spotify_id,
            stream_count=stream.stream_count,
            type=stream.type,
          )
          for stream in streams
        ]

  streams = read_spotify_streams(db)
  return [
    Spotify_Streams_Response(
      spotify_id=stream.spotify_id,
      stream_count=stream.stream_count,
      type=stream.type,
    )
    for stream in streams
  ]
