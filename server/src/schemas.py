from pydantic import BaseModel
from datetime import datetime, time

# emotions
class Emotions_Response(BaseModel):
  emotion_id: int
  emotion_label: str

  class Config:
    from_attributes = True

# user
class User_Response(BaseModel):
  username: str
  email:str
  joined_at: datetime

  class Config:
    from_attributes = True

# token_type
class Token_Type_Response(BaseModel):
  token_type_id: int
  type_name: str

  class Config:
    from_attributes = True

# audio_type
class Audio_Type_Response(BaseModel):
  audio_type_id: int
  type_name: str

  class Config:
    from_attributes = True

# token
class Spotify_Token_Request(BaseModel):
  code: str
  code_verifier: str

class Token_Response(BaseModel):
  access_token: str
  refresh_token: str
  jwt_token: str

# album
class Album_Base(BaseModel):
  album_cover: str
  album_name: str
  description: str

class Album_Create(Album_Base):
  user_id: int

class Album_Response(Album_Base):
  album_id: int
  created_at: datetime
  modified_at: datetime

  class Config:
    from_attributes = True

# audio
class Audio_Base(BaseModel):
  audio_type_id: int
  album_id: int
  emotion_id: int
  visibility: str
  audio_photo: str
  audio_record: str
  audio_title: str
  description: str
  duration: time

class Audio_Create(Audio_Base):
  user_id: int

class Audio_Response(Audio_Base):
  audio_id: int
  created_at: datetime
  modified_at: datetime

  class Config:
    from_attributes = True
