from sqlalchemy.orm import relationship
from sqlalchemy import Column, String, Integer, DateTime, Time, ForeignKey, Enum as SqlEnum, func
from enum import Enum

from src.database import Base

class Audio_Visibility(str, Enum):
  public = 'public'
  private = 'private'

class Audio_Type(Base):
  __tablename__ = 'audio_type'
  audio_type_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  type_name = Column(String(20), nullable=False)

  audio = relationship('Audio', back_populates='audio_type', cascade='all, delete-orphan')

class Audio(Base):
  __tablename__ = 'audio'
  audio_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  user_id = Column(Integer, ForeignKey('user.user_id', ondelete='CASCADE'), nullable=True)
  audio_type_id = Column(Integer, ForeignKey('audio_type.audio_type_id', ondelete='CASCADE'), nullable=False)
  album_id = Column(Integer, ForeignKey('album.album_id', ondelete='SET NULL'), nullable=True) 
  emotion_id = Column(Integer, ForeignKey('emotions.emotion_id', ondelete='SET NULL'), nullable=True) 
  visibility = Column(SqlEnum(Audio_Visibility, name="audio_visibility"), nullable=False)
  audio_photo = Column(String(1000), index=True)
  audio_record = Column(String(1000), index=True)
  audio_title = Column(String(50), nullable=False, index=True)
  description = Column(String(1000), nullable=False, index=True)
  duration = Column(Time(timezone=True), nullable=False, index=True)
  created_at = Column(DateTime(timezone=True), default=func.now())
  modified_at = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now())

  user = relationship('User', back_populates='audio')
  audio_type = relationship('Audio_Type', back_populates='audio')
  album = relationship('Album', back_populates='audio')
  emotion = relationship('Emotions', back_populates='audio')
