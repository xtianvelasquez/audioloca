import os

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from dotenv import load_dotenv
load_dotenv()

db_url = os.getenv("DATABASE_URL")
if not db_url:
  raise ValueError("DATABASE_URL is not set.")

engine = create_engine(db_url)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
  db = SessionLocal()
  try:
    yield db
  finally:
    db.close()

def init_db():
  from src import models
  from src.crud import token_type_initializer, genre_initializer, initialize_tracks

  Base.metadata.create_all(bind=engine)
  db = SessionLocal()
  try:
    token_type_initializer(db)
    genre_initializer(db)
    initialize_tracks(db)
  finally:
    db.close()
