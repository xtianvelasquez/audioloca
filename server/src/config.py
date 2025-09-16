from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

MANILA = ZoneInfo("Asia/Manila")
TOKEN_EXPIRATION = datetime.utcnow().replace(second=0, microsecond=0) + timedelta(days=29) # Token expires in 29 days

VALID_PHOTO_EXTENSION = [".jpg", ".jpeg", ".png"]
VALID_AUDIO_EXTENSION = [".mp3", ".aac", ".wav", ".x-wav"]

TOKEN_TYPE = {
  "ACCESS_TOKEN": 1,
  "REFRESH_TOKEN": 2,
  "JWT_TOKEN": 3
}

GENRES = {
  "pop": 1,
  "hip-hop/rap": 2,
  "rock": 3,
  "jazz/blues": 4,
  "classical": 5,
  "folk/acoustic": 6,
  "latin/world": 7,
  "ambient/chill": 8,
  "metal": 9,
  "experimental": 10,
  "country": 11,
  "electronic": 12
}
