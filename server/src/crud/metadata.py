import sys
import os
import json

# Add project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

from src.crud.create import store_specific_user, store_album, store_audio
from src.crud.read import read_username, read_album_by_name
from src.config import GENRES

def normalize_text(text):
    return text.replace(" ", "").lower()

def get_genre_by_name(genre_name: str):
    return GENRES.get(genre_name.lower())

# Load metadata
with open("media/fma/metadata.json", "r", encoding="utf-8") as f:
    data = json.load(f)

def initialize_tracks(db):
    for track in data:
        # Parse genres
        genre = track["genre"].split(",")
        genres_cleaned = [g.strip().lower() for g in genre]

        genre_descriptions = []
        for g in genres_cleaned:
            subgenres = g.split("/")
            for sub in subgenres:
                description = get_genre_by_name(sub)
                if description:
                    genre_descriptions.append(description)

        # Normalize artist info
        username = normalize_text(track["artist"])
        email = username + "@sample.com"
        password = username

        # Ensure user exists
        user = read_username(db, username)
        if user is None:
            store_specific_user(db, None, email, username, password)
            user = read_username(db, username)

        # Normalize album info
        album_name = track["album"]
        album_cover = "media/fma/covers/" + album_name.replace(":", "_") + ".jpg"

        # Ensure album exists
        album = read_album_by_name(db, user.user_id, album_name)
        if album is None:
            store_album(db, user.user_id, album_cover, album_name)
            album = read_album_by_name(db, user.user_id, album_name)

        # Create audio
        audio_record_path = "media/fma/audios/" + track["album"] + "/" + track["filename"]
        audio_title = track["title"]
        duration = "00:" + track["duration"]

        for description in genre_descriptions:
            store_audio(
                db,
                user.user_id,
                description,
                album.album_id,
                "public",
                audio_record_path,
                audio_title,
                duration
            )
