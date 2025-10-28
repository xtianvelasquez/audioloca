import os, shutil, uuid
from fastapi import HTTPException, APIRouter, UploadFile, Body, Form, File, Depends
from typing import List

from sqlalchemy.orm import Session

from src.database import get_db
from src.security import verify_token
from src.crud import store_album, read_all_album, read_specific_album, delete_specific_album
from src.utils import validate_file_extension
from src.schemas import Album_Response
from src.config import VALID_PHOTO_EXTENSION, VALID_PHOTO_MIME_TYPES

router = APIRouter()

def build_album_response(album) -> Album_Response:
  return Album_Response(
    album_cover=album.album_cover,
    album_name=album.album_name,
    album_id=album.album_id,
    username=album.user.username,
    created_at=album.created_at,
    modified_at=album.modified_at
  )

@router.post("/audioloca/album/create",  response_model=Album_Response, status_code=201)
async def album_created(
    album_name: str = Form(...),
    album_cover: UploadFile = File(...),
    token_payload = Depends(verify_token),
    db: Session = Depends(get_db)
  ):
  user_id = token_payload.get('payload', {}).get('sub')

  if len(album_name) > 100:
    raise HTTPException(status_code=400, detail="Name must be 100 characters or fewer.")

  if not validate_file_extension(album_cover, VALID_PHOTO_EXTENSION):
    raise HTTPException(status_code=400, detail="Invalid photo file type.")
  
  if album_cover.content_type not in VALID_PHOTO_MIME_TYPES:
    raise HTTPException(status_code=400, detail="Invalid photo MIME type.")

  safe_name = album_cover.filename.replace(" ", "_")
  cover_ext = os.path.splitext(safe_name)[1]
  cover_path = f"media/covers/{uuid.uuid4().hex}{cover_ext}"

  os.makedirs(os.path.dirname(cover_path), exist_ok=True)

  try:
    with open(cover_path, "wb") as buffer:
      shutil.copyfileobj(album_cover.file, buffer)
  finally:
    album_cover.file.close()

  album = store_album(
    db,
    user_id,
    cover_path,
    album_name
  )

  if not album:
    raise HTTPException(status_code=500, detail="Album creation failed.")

  return build_album_response(album)

@router.get("/audioloca/albums/read", response_model=List[Album_Response], status_code=200)
async def album_read(token_payload = Depends(verify_token), db: Session = Depends(get_db)):
  user_id = token_payload.get('payload', {}).get('sub')
  albums = read_all_album(db, user_id)
  return [build_album_response(album) for album in albums]

@router.post("/audioloca/album/read", response_model=Album_Response, status_code=200)
async def specific_album_read(
  album_id: int = Body(..., embed=True),
  token_payload = Depends(verify_token),
  db: Session = Depends(get_db)
  ):
  user_id = token_payload.get('payload', {}).get('sub')
  album = read_specific_album(db, user_id, album_id)

  return build_album_response(album)

@router.post("/audioloca/album/delete", status_code=200)
async def album_delete(
  album_id: int = Body(..., embed=True),
  token_payload = Depends(verify_token),
  db: Session = Depends(get_db)
):
  user_id = token_payload.get('payload', {}).get('sub')
  deleted_album = delete_specific_album(db, user_id, album_id)

  if not deleted_album:
    raise HTTPException(status_code=404, detail="Album not found or already deleted.")

  if os.path.exists(deleted_album.album_cover):
    os.remove(deleted_album.album_cover)

  return {"detail": "Album deleted successfully."}
