from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from src.database import get_db
from src.security import verify_token
from src.crud import (store_stream, store_location,
                      read_location, read_local_audio_location, read_spotify_audio_location,
                      read_local_streams, read_spotify_streams, read_bounding_location)
from src.schemas import Locations_Base, Streams_Create, Local_Stream, Spotify_Stream
from typing import List
from math import radians, cos

router = APIRouter()

def build_local_stream(stream) -> Local_Stream:
  return Local_Stream(
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

def build_spotify_stream(stream) -> Spotify_Stream:
  return Spotify_Stream(
    spotify_id=stream.spotify_id,
    stream_count=stream.stream_count,
    type=stream.type,
  )

@router.post("/audio/stream", status_code=201)
async def send_stream(
  data: Streams_Create,
  token_payload=Depends(verify_token),
  db: Session = Depends(get_db)
  ):
  user_id = token_payload.get("payload", {}).get("sub")

  location = read_location(db, data.latitude, data.longitude, 6)
  if location is None:
    location = store_location(db, data.latitude, data.longitude)

  if data.type == "local":
    store_stream(db, user_id, location.location_id, data.audio_id, None, data.type)
  else:
    store_stream(db, user_id, location.location_id, None, data.spotify_id, data.type)

  return {"message": "Stream recorded successfully."}

@router.post("/audioloca/audio/location", response_model=List[Local_Stream], status_code=200)
async def audio_location_local(data: Locations_Base, db: Session = Depends(get_db)):
  lat = data.latitude
  lon = data.longitude

  print(f"Frontend request received with latitude: {lat}, longitude: {lon}")

  radius_m = 100
  radius_deg_lat = radius_m / 111_320
  radius_deg_lon = radius_m / (111_320 * cos(radians(lat)))

  min_lat = lat - radius_deg_lat
  max_lat = lat + radius_deg_lat
  min_lon = lon - radius_deg_lon
  max_lon = lon + radius_deg_lon

  locations = read_bounding_location(db, min_lat, max_lat, min_lon, max_lon)

  results = []
  for location in locations:
    streams = read_local_audio_location(db, location.location_id)
    for stream in streams:
      if stream.audio.visibility == "public":
        print(f"Fetched audio: {stream.audio.audio_title} at lat: {location.latitude}, lon: {location.longitude}")
        results.append(build_local_stream(stream))

  print(f"Total public audio streams fetched: {len(results)}")

  if results:
    return results

  streams = read_local_streams(db)
  return [build_local_stream(stream) for stream in streams if stream.audio.visibility == "public"]

@router.post("/spotify/audio/location", response_model=List[Spotify_Stream], status_code=200)
async def audio_location_spotify(data: Locations_Base, db: Session = Depends(get_db)):
  for precision in [6, 5, 4, 3, 2, 1]:
    location = read_location(db, data.latitude, data.longitude, precision)

    if location:
      streams = read_spotify_audio_location(db, location.location_id)
      if streams:
        return [build_spotify_stream(stream) for stream in streams]

  streams = read_spotify_streams(db)
  return [build_spotify_stream(stream) for stream in streams]
