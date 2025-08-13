import os, shutil, uuid
from fastapi import HTTPException, APIRouter, UploadFile, Body, Form, File, Depends
from typing import List

from sqlalchemy.orm import Session

from src.database import get_db
from src.security import verify_token
from src.crud import store_audio, read_audio_type, read_all_audio, read_specific_audio, read_audio_album
from src.utils import validate_file_extension
from src.schemas import Audio_Type_Response, Audio_Response
from src.config import VALID_PHOTO_EXTENSION, VALID_AUDIO_EXTENSION

router = APIRouter()

@router.get("/audioloca/audio/type", response_model=List[Audio_Type_Response], status_code=200)
async def audio_type_read(db: Session = Depends(get_db)):
  audio_types = read_audio_type(db)
  return audio_types

@router.post("/audioloca/audio/create", status_code=201)
async def audio_created(
    audio_type_id: int = Form(...),
    album_id: int = Form(...),
    emotion_id: int = Form(...),
    duration: str = File(...),
    visibility: str = Form(...),
    audio_title: str = Form(...),
    description: str = Form(...),
    audio_photo: UploadFile = File(...),
    audio_record: UploadFile = File(...),
    token_payload = Depends(verify_token),
    db: Session = Depends(get_db)
  ):
  user_id = token_payload.get('payload', {}).get('sub')

  if len(audio_title) > 50:
    raise HTTPException(status_code=400, detail="Title must be 50 characters or fewer.")
  
  if len(description) > 1000:
    raise HTTPException(status_code=400, detail="Description must be 1000 characters or fewer.")

  if not validate_file_extension(audio_photo, VALID_PHOTO_EXTENSION):
    raise HTTPException(status_code=400, detail="Invalid photo file type.")
  if not validate_file_extension(audio_record, VALID_AUDIO_EXTENSION):
    raise HTTPException(status_code=400, detail="Invalid audio file type.")
  
  if audio_photo.content_type not in ["image/jpg", "image/jpeg", "image/png"]:
    raise HTTPException(status_code=400, detail="Invalid photo MIME type.")
  
  if audio_record.content_type not in ["audio/mp3", "audio/aac", "audio/wav", "audio/x-wav"]:
    raise HTTPException(status_code=400, detail="Invalid audio MIME type.")

  photo_ext = os.path.splitext(audio_photo.filename)[1]
  audio_ext = os.path.splitext(audio_record.filename)[1]

  photo_path = f"media/photos/{uuid.uuid4().hex}{photo_ext}"
  audio_path = f"media/audios/{uuid.uuid4().hex}{audio_ext}"

  os.makedirs(os.path.dirname(photo_path), exist_ok=True)
  os.makedirs(os.path.dirname(audio_path), exist_ok=True)

  with open(photo_path, "wb") as f:
    shutil.copyfileobj(audio_photo.file, f)
  with open(audio_path, "wb") as f:
    shutil.copyfileobj(audio_record.file, f)

  audio = store_audio(
    db,
    user_id,
    audio_type_id,
    album_id,
    emotion_id,
    visibility,
    photo_path,
    audio_path,
    audio_title,
    description,
    duration
  )

  if not audio:
    raise HTTPException(status_code=500, detail="Audio creation failed.")

  return { 'message': 'Audio has been successfully stored.' }

@router.get("/audioloca/audio/read", response_model=List[Audio_Response], status_code=200)
async def audio_read(token_payload = Depends(verify_token), db: Session = Depends(get_db)):
  user_id = token_payload.get('payload', {}).get('sub')
  audios = read_all_audio(db, user_id)
  return audios

@router.post("/audioloca/audio", response_model=Audio_Response, status_code=200)
async def specific_audio_read(audio_id: int, token_payload = Depends(verify_token), db: Session = Depends(get_db)):
  user_id = token_payload.get('payload', {}).get('sub')
  audio = read_specific_audio(db, user_id, audio_id)
  return audio

@router.post("/audioloca/audio/album", response_model=List[Audio_Response], status_code=200)
async def specific_audio_read(album_id: int = Body(..., embed=True), token_payload = Depends(verify_token), db: Session = Depends(get_db)):
  user_id = token_payload.get('payload', {}).get('sub')
  audio_album = read_audio_album(db, user_id, album_id)
  return audio_album
