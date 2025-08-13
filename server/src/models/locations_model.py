from sqlalchemy.orm import relationship
from sqlalchemy import Column, String, Integer, DECIMAL

from src.database import Base

class Locations(Base):
  __tablename__ = 'locations'
  location_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  location_label = Column(String, nullable=True, index=True)
  latitude = Column(DECIMAL(10,8), nullable=False)
  longitude = Column(DECIMAL(11,8), nullable=False)

  streams = relationship('Streams', back_populates='locations')
