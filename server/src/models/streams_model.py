from sqlalchemy.orm import relationship
from sqlalchemy import UniqueConstraint, Column, String, Integer, DateTime, ForeignKey, Enum as SqlEnum, func
from enum import Enum

from src.database import Base

class Stream_Type(str, Enum):
  local = "local"
  spotify = "spotify"

class Streams(Base):
  __tablename__ = "streams"
  stream_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  user_id = Column(Integer, ForeignKey("user.user_id", ondelete="SET NULL"), index=True, nullable=True)
  spotify_id = Column(String(50), index=True, nullable=True)
  location_id = Column(Integer, ForeignKey("locations.location_id", ondelete="SET NULL"), index=True, nullable=True)
  audio_id = Column(Integer, ForeignKey("audio.audio_id", ondelete="CASCADE"), index=True, nullable=True)
  type = Column(SqlEnum(Stream_Type, name="stream_type"), nullable=False)
  stream_count = Column(Integer, nullable=True, default=0)
  last_played = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now())

  __table_args__ = (
    UniqueConstraint("user_id", "audio_id", "spotify_id", name="uq_user_audio"),
  )

  user = relationship("User", back_populates="streams")
  audio = relationship("Audio", back_populates="streams")
  locations = relationship("Locations", back_populates="streams")
