from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

MANILA = ZoneInfo('Asia/Manila')
TOKEN_EXPIRATION = datetime.utcnow().replace(second=0, microsecond=0) + timedelta(days=29) # Token expires in 29 days

VALID_PHOTO_EXTENSION = [".jpg", ".jpeg", ".png"]
VALID_AUDIO_EXTENSION = [".mp3", ".aac", ".wav", ".x-wav"]

EMOTIONS = {
  "ANGRY": 1,
  "DISGUST": 2,
  "FEAR": 3,
  "HAPPY": 4,
  "SAD": 5,
  "SURPRISE": 6,
  "NEUTRAL": 7
}

TOKEN_TYPE = {
  "ACCESS_TOKEN": 1,
  "REFRESH_TOKEN": 2,
  "JWT_TOKEN": 3
}

AUDIO_TYPE = {
  "SONG": 1,
  "SPEECH": 2,
  "PODCAST": 3,
  "AUDIOBOOK": 4,
  "SPOKEN_POETRY": 5,
  "CONVO": 6
}
