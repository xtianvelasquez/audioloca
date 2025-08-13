from fastapi import APIRouter, Depends
from typing import List

from sqlalchemy.orm import Session

from src.database import get_db
from src.crud import read_all_emotion
from src.schemas import Emotions_Response

router = APIRouter()

@router.get("/audioloca/emotions/read", response_model=List[Emotions_Response], status_code=200)
async def emotions_read(db: Session = Depends(get_db)):
  emotions = read_all_emotion(db)
  return emotions
