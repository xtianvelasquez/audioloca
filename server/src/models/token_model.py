from sqlalchemy.orm import relationship
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, Boolean, text

from src.database import Base

class Token_Type(Base):
  __tablename__ = 'token_type'
  token_type_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  type_name = Column(String(20), nullable=False)

  token = relationship('Token', back_populates='token_type', cascade='all, delete-orphan')

class Token(Base):
  __tablename__ = 'token'
  token_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  user_id = Column(Integer, ForeignKey('user.user_id', ondelete='SET NULL'), nullable=True)
  token_type_id = Column(Integer, ForeignKey('token_type.token_type_id', ondelete='CASCADE'), nullable=False)
  token_hash = Column(String(500), nullable=False)
  is_active = Column(Boolean, default=True, server_default=text('true'))
  issued_at = Column(DateTime(timezone=True))
  expires_at = Column(DateTime(timezone=True), nullable=True)
  revoked_at = Column(DateTime(timezone=True))

  user = relationship('User', back_populates='token')
  token_type = relationship('Token_Type', back_populates='token')
