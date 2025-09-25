from sqlalchemy.orm import relationship
from sqlalchemy import Column, String, Integer, DateTime, Time, ForeignKey, Enum as SqlEnum, func
from enum import Enum

from src.database import Base

class Audio_Visibility(str, Enum):
  public = "public"
  private = "private"

class Audio(Base):
  __tablename__ = "audio"
  audio_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  user_id = Column(Integer, ForeignKey("user.user_id", ondelete="CASCADE"), nullable=True)
  genre_id = Column(Integer, ForeignKey("genres.genre_id", ondelete="CASCADE"), nullable=False)
  album_id = Column(Integer, ForeignKey("album.album_id", ondelete="SET NULL"), nullable=True)
  visibility = Column(SqlEnum(Audio_Visibility, name="audio_visibility"), nullable=False)
  audio_record = Column(String(1000), index=True)
  audio_title = Column(String(100), nullable=False, index=True)
  duration = Column(Time(timezone=True), nullable=False, index=True)
  created_at = Column(DateTime(timezone=True), server_default=func.now())
  modified_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

  user = relationship("User", back_populates="audio")
  genre = relationship("Genres", back_populates="audio")
  album = relationship("Album", back_populates="audio")
  streams = relationship("Streams", back_populates="audio", cascade="all, delete-orphan")
