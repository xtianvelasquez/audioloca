import os, shutil, uuid
from fastapi import HTTPException, APIRouter, UploadFile, Body, Form, File, Depends
from typing import List

from sqlalchemy.orm import Session

from src.database import get_db
from src.security import verify_token
from src.crud import read_genre_by_id, store_audio, read_all_audio, read_specific_audio, read_audio_album, read_audio_by_genre, link_audio_to_genre
from src.utils import validate_file_extension
from src.schemas import Genres_Response, Audio_Response
from src.config import VALID_AUDIO_EXTENSION

router = APIRouter()

def build_audio_response(audio) -> Audio_Response:
  return Audio_Response(
    genres=[Genres_Response(genre_id=link.genre.genre_id, genre_name=link.genre.genre_name) for link in audio.genre_links],
    album_id=audio.album_id,
    visibility=audio.visibility,
    audio_record=audio.audio_record,
    audio_title=audio.audio_title,
    duration=audio.duration,
    audio_id=audio.audio_id,
    username=audio.user.username,
    album_cover=audio.album.album_cover,
    stream_count=sum(stream.stream_count for stream in audio.streams),
    created_at=audio.created_at,
    modified_at=audio.modified_at
  )

@router.post("/audioloca/audio/genre", response_model=List[Audio_Response], status_code=200)
async def audio_genre_read(genre_id: int = Body(..., embed=True), db: Session = Depends(get_db)):
  audios = read_audio_by_genre(db, genre_id)

  return [build_audio_response(audio) for audio in audios]

@router.post("/audioloca/audio/create", response_model=Audio_Response, status_code=201)
async def audio_created(
    genre_id: List[int] = Form(...),
    album_id: int = Form(...),
    visibility: str = Form(...),
    audio_title: str = Form(...),
    duration: str = Form(...),
    audio_record: UploadFile = File(...),
    token_payload = Depends(verify_token),
    db: Session = Depends(get_db)
  ):
  user_id = token_payload.get("payload", {}).get("sub")

  if len(audio_title) > 100:
    raise HTTPException(status_code=400, detail="Title must be 100 characters or fewer.")

  if not validate_file_extension(audio_record, VALID_AUDIO_EXTENSION):
    raise HTTPException(status_code=400, detail="Invalid audio file type.")
  
  if audio_record.content_type not in ["audio/mp3", "audio/aac", "audio/wav", "audio/x-wav"]:
    raise HTTPException(status_code=400, detail="Invalid audio MIME type.")

  audio_ext = os.path.splitext(audio_record.filename)[1]

  audio_path = f"media/audios/{uuid.uuid4().hex}{audio_ext}"

  os.makedirs(os.path.dirname(audio_path), exist_ok=True)

  with open(audio_path, "wb") as f:
    shutil.copyfileobj(audio_record.file, f)

  audio = store_audio(
    db,
    user_id,
    album_id,
    visibility,
    audio_path,
    audio_title,
    duration
  )

  if not audio:
    raise HTTPException(status_code=500, detail="Audio creation failed.")

  for genre_id_single in genre_id:
    genre = read_genre_by_id(db, genre_id_single)
    if genre:
      link_audio_to_genre(db, audio.audio_id, genre.genre_id)

  return build_audio_response(audio)

@router.post("/audioloca/audio/read", response_model=Audio_Response, status_code=200)
async def specific_audio_read(audio_id: int, token_payload = Depends(verify_token), db: Session = Depends(get_db)):
  user_id = token_payload.get("payload", {}).get("sub")
  audio = read_specific_audio(db, user_id, audio_id)
  
  return build_audio_response(audio)

@router.get("/audioloca/audios/read", response_model=List[Audio_Response], status_code=200)
async def audio_read(token_payload = Depends(verify_token), db: Session = Depends(get_db)):
  user_id = token_payload.get("payload", {}).get("sub")
  audios = read_all_audio(db, user_id)
  
  return [build_audio_response(audio) for audio in audios]

@router.post("/audioloca/audio/album", response_model=List[Audio_Response], status_code=200)
async def audio_album_read(
  album_id: int = Body(..., embed=True),
  token_payload = Depends(verify_token),
  db: Session = Depends(get_db)
  ):
  user_id = token_payload.get("payload", {}).get("sub")
  audios = read_audio_album(db, user_id, album_id)
  
  return [build_audio_response(audio) for audio in audios]
