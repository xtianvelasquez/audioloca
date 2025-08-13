from fastapi import APIRouter
from src.api import emotions, oauth, album, audio

router = APIRouter()

router.include_router(emotions.router, tags=['Emotions'])
router.include_router(oauth.router, tags=['OAuth'])
router.include_router(album.router, tags=['Album'])
router.include_router(audio.router, tags=['Audio'])
