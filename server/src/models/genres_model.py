from sqlalchemy.orm import relationship
from sqlalchemy import Column, String, Integer

from src.database import Base

class Genres(Base):
  __tablename__ = "genres"
  genre_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  genre_name = Column(String(50), unique=True, index=True, nullable=False)

  audio = relationship("Audio", back_populates="genre", uselist=True, cascade="all, delete-orphan")
