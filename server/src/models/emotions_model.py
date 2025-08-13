from sqlalchemy.orm import relationship
from sqlalchemy import Column, String, Integer

from src.database import Base

class Emotions(Base):
  __tablename__ = 'emotions'
  emotion_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  emotion_label = Column(String(50), nullable=False, index=True)

  audio = relationship('Audio', back_populates='emotion', uselist=True)
