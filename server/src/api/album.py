import os, shutil, uuid
from fastapi import HTTPException, APIRouter, UploadFile, Body, Form, File, Depends
from typing import List

from sqlalchemy.orm import Session

from src.database import get_db
from src.security import verify_token
from src.crud import store_album, read_all_album, read_specific_album
from src.utils import validate_file_extension
from src.schemas import Album_Response
from src.config import VALID_PHOTO_EXTENSION

router = APIRouter()

@router.post("/audioloca/album/create", status_code=201)
async def album_created(
    album_name: str = Form(...),
    description: str = Form(...),
    album_cover: UploadFile = File(...),
    token_payload = Depends(verify_token),
    db: Session = Depends(get_db)
  ):
  user_id = token_payload.get('payload', {}).get('sub')

  if len(album_name) > 50:
    raise HTTPException(status_code=400, detail="Name must be 50 characters or fewer.")
  
  if len(description) > 1000:
    raise HTTPException(status_code=400, detail="Description must be 1000 characters or fewer.")

  if not validate_file_extension(album_cover, VALID_PHOTO_EXTENSION):
    raise HTTPException(status_code=400, detail="Invalid photo file type.")
  
  if album_cover.content_type not in ["image/jpg", "image/jpeg", "image/png"]:
    raise HTTPException(status_code=400, detail="Invalid photo MIME type.")

  cover_ext = os.path.splitext(album_cover.filename)[1]

  cover_path = f"media/covers/{uuid.uuid4().hex}{cover_ext}"

  os.makedirs(os.path.dirname(cover_path), exist_ok=True)

  with open(cover_path, "wb") as f:
    shutil.copyfileobj(album_cover.file, f)

  album = store_album(
    db,
    user_id,
    cover_path,
    album_name,
    description
  )

  if not album:
    raise HTTPException(status_code=500, detail="Album creation failed.")

  return { 'message': 'Album has been successfully stored.' }

@router.get("/audioloca/albums/read", response_model=List[Album_Response], status_code=200)
async def album_read(token_payload = Depends(verify_token), db: Session = Depends(get_db)):
  user_id = token_payload.get('payload', {}).get('sub')
  albums = read_all_album(db, user_id)
  return [
    Album_Response(
      album_cover=album.album_cover,
      album_name=album.album_name,
      description=album.description,
      album_id=album.album_id,
      username=album.user.username,
      created_at=album.created_at,
      modified_at=album.modified_at
    )
    
    for album in albums
  ]

@router.post("/audioloca/album/read", response_model=Album_Response, status_code=200)
async def specific_album_read(album_id: int = Body(..., embed=True), token_payload = Depends(verify_token), db: Session = Depends(get_db)):
  user_id = token_payload.get('payload', {}).get('sub')
  album = read_specific_album(db, user_id, album_id)

  return Album_Response(
    album_cover=album.album_cover,
    album_name=album.album_name,
    description=album.description,
    album_id=album.album_id,
    username=album.user.username,
    created_at=album.created_at,
    modified_at=album.modified_at
  )
