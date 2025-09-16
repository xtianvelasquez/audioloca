from sqlalchemy.orm import relationship
from sqlalchemy import Column, String, Integer, DateTime, func

from src.database import Base

class User(Base):
  __tablename__ = "user"
  user_id = Column(Integer, primary_key=True, autoincrement=True)
  spotify_id = Column(String(255), unique=True, index=True, nullable=True)
  email = Column(String(255), unique=True, nullable=False)
  username = Column(String(50), unique=True, nullable=False, index=True)
  password = Column(String(255), nullable=True, index=True)
  joined_at = Column(DateTime(timezone=True), default=func.now())

  token = relationship("Token", back_populates="user", uselist=False)
  album = relationship("Album", back_populates="user", cascade="all, delete-orphan")
  audio = relationship("Audio", back_populates="user", cascade="all, delete-orphan")
  streams = relationship("Streams", back_populates="user")
