from fastapi import APIRouter
from src.api import genres
from src.api import oauth, album, audio, stream

router = APIRouter()

router.include_router(genres.router, tags=['Genres'])
router.include_router(oauth.router, tags=['OAuth'])
router.include_router(album.router, tags=['Album'])
router.include_router(audio.router, tags=['Audio'])
router.include_router(stream.router, tags=['Stream'])
