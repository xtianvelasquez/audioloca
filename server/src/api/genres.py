from fastapi import APIRouter, Depends
from typing import List

from sqlalchemy.orm import Session

from src.database import get_db
from src.crud import read_genres
from src.schemas import Genres_Response

router = APIRouter()

@router.get("/audioloca/genres/read", response_model=List[Genres_Response], status_code=200)
async def genres_read(db: Session = Depends(get_db)):
  genres = read_genres(db)
  return genres
