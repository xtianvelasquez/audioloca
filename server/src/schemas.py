from pydantic import BaseModel, ConfigDict
from typing import Literal
from datetime import datetime, time
from enum import Enum

# visibility
class Visibility(str, Enum):
  public = "public"
  private = "private"

# stream type
class Stream_Type(str, Enum):
  local = "local"
  spotify = "spotify"

# user
class User_Base(BaseModel):
  username: str
  password: str

class User_Create(User_Base):
  email: str

class User_Response(BaseModel):
  username: str
  email: str
  joined_at: datetime

  model_config = ConfigDict(from_attributes=True, extra="ignore")

# token_type
class Token_Type_Response(BaseModel):
  token_type_id: int
  type_name: str

  model_config = ConfigDict(from_attributes=True, extra="ignore")

# token
class Spotify_Token_Request(BaseModel):
  code: str
  code_verifier: str

class Spotify_Token_Response(BaseModel):
  access_token: str
  expires_at: datetime
  refresh_token: str
  jwt_token: str

  model_config = ConfigDict(from_attributes=True, extra="ignore")

class Local_Token_Response(BaseModel):
  jwt_token: str
  token_type: Literal["Bearer"]

  model_config = ConfigDict(from_attributes=True, extra="ignore")

# album
class Album_Base(BaseModel):
  album_cover: str
  album_name: str
  description: str

class Album_Create(Album_Base):
  user_id: int

class Album_Response(Album_Base):
  album_id: int
  username: str # from user table
  created_at: datetime
  modified_at: datetime

  model_config = ConfigDict(from_attributes=True)

# genres
class Genres_Response(BaseModel):
  genre_id: int
  genre_name: str

  model_config = ConfigDict(from_attributes=True, extra="ignore")

# audio
class Audio_Base(BaseModel):
  genre_id: int
  album_id: int
  visibility: Visibility
  audio_record: str
  audio_title: str
  description: str
  duration: time

class Audio_Create(Audio_Base):
  user_id: int

class Audio_Response(Audio_Base):
  audio_id: int
  username: str # from user table
  album_cover: str # from album table
  stream_count: int # from streams table
  created_at: datetime
  modified_at: datetime

  model_config = ConfigDict(from_attributes=True, extra="ignore")

# locations
class Locations_Base(BaseModel):
  latitude: float
  longitude: float

# streams
class Streams_Create(Locations_Base):
  audio_id: int | None = None
  spotify_id: str | None = None
  type: Stream_Type

class Local_Streams_Response(BaseModel):
  audio_id: int
  username: str # from user table
  album_cover: str # from album table
  stream_count: int # from streams table
  album_id: int
  audio_record: str
  audio_title: str
  description: str
  duration: time
  type: Stream_Type

class Spotify_Streams_Response(BaseModel):
  spotify_id: str
  stream_count: int
  type: Stream_Type
