import sys
import os
import json

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

from src.crud import (store_specific_user, store_album, store_audio, link_audio_to_genre,
                      read_username, read_genre_by_id, read_album_by_name, read_audio_by_path_and_title)
from src.config import GENRES

def normalize_text(text):
    return text.replace(" ", "").lower()

def get_genre_by_id(genre_name: str):
    return GENRES.get(genre_name.lower())

with open("media/fma/metadata.json", "r", encoding="utf-8") as f:
    data = json.load(f)

def initialize_local_tracks(db):
    for track in data:
        # Parse genres
        genre_list = [g.strip().lower() for g in track["genre"].split(",")]

        genre_descriptions = []
        for g in genre_list:
            description = get_genre_by_id(g)
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

        # Normalize audio info
        audio_record_path = "media/fma/audios/" + track["album"].replace(":", "_") + "/" + track["filename"]
        audio_title = track["title"]
        duration = "00:" + track["duration"]

        # Ensure audio does not already exist
        audio = read_audio_by_path_and_title(db, user.user_id, audio_record_path, audio_title)
        if audio is None:
            audio = store_audio(
                db,
                user.user_id,
                album.album_id,
                "public",
                audio_record_path,
                audio_title,
                duration
            )
        else:
            audio_id = audio.audio_id

        for description in genre_descriptions:
            genre = read_genre_by_id(db, description)
            if genre:
                link_audio_to_genre(db, audio.audio_id, genre.genre_id)
