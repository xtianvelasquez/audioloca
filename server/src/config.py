from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

MANILA = ZoneInfo("Asia/Manila")
TOKEN_EXPIRATION = datetime.utcnow().replace(second=0, microsecond=0) + timedelta(days=29) # Token expires in 29 days

VALID_PHOTO_EXTENSION = [".jpg", ".jpeg", ".png"]
VALID_AUDIO_EXTENSION = [".mp3", ".aac", ".wav", ".x-wav"]

VALID_AUDIO_MIME_TYPES = [
  "audio/mp3", "audio/mpeg", "audio/aac", "audio/x-aac",
  "audio/wav", "audio/x-wav", "audio/ogg", "audio/x-m4a"
]
VALID_PHOTO_MIME_TYPES = [
  "image/jpg", "image/jpeg", "image/png"
]

TOKEN_TYPE = {
  "ACCESS_TOKEN": 1,
  "REFRESH_TOKEN": 2,
  "JWT_TOKEN": 3
}

GENRES = {
  "pop": 1, # Moonbow Songs, Vol. 1, PARNI NA RAIONE
  "hip-hop/rap": 2, # Ain't no holding back, SCAMMER
  "rock": 3, # Motivation_ The Anthem, Taylor & Lopker
  "jazz/blues": 4, # Vintage Beats, recognition blues
  "classical": 5, # Orchestral Miniatures
  "folk/acoustic": 6, # Ancient lands, Celtic Routes
  "latin/world": 7,
  "ambient/chill": 8, # Fathomless - Ambient, Ambient Atmospheres
  "metal": 9, # Iron Metal I Rock on the Hole, Metal Energy
  "experimental": 10, # Metamorphosis, Wires on Words
  "country": 11, # Citizens Unite, Kurplunk
  "electronic": 12 # Marginal
}
