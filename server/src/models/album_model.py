from sqlalchemy.orm import relationship
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, func

from src.database import Base

class Album(Base):
  __tablename__ = 'album'
  album_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  user_id = Column(Integer, ForeignKey('user.user_id', ondelete='CASCADE'), nullable=True) 
  album_cover = Column(String(1000), index=True)
  album_name = Column(String(50), nullable=False, index=True)
  description = Column(String(1000), nullable=False, index=True)
  created_at = Column(DateTime(timezone=True), default=func.now())
  modified_at = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now())

  user = relationship('User', back_populates='album')
  audio = relationship('Audio', back_populates='album', uselist=False)
