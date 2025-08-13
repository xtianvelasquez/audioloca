from sqlalchemy.orm import relationship
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, func

from src.database import Base

class Streams(Base):
  __tablename__ = 'streams'
  stream_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  user_id = Column(Integer, ForeignKey('user.user_id', ondelete='SET NULL'), index=True, nullable=True)
  location_id = Column(Integer, ForeignKey('locations.location_id', ondelete='SET NULL'), index=True, nullable=True)
  audio_id = Column(String(20), index=True, nullable=True)
  stream_count = Column(Integer, nullable=True)
  last_played = Column(DateTime(timezone=True), default=func.now(), index=True)

  user = relationship('User', back_populates='streams')
  locations = relationship('Locations', back_populates='streams')
