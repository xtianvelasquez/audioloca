import os
from fastapi import UploadFile
import base64, hashlib

def generate_challenge_from_verifier(verifier: str) -> str:
  hashed = hashlib.sha256(verifier.encode()).digest()
  return base64.urlsafe_b64encode(hashed).decode('utf-8').rstrip('=')

def validate_file_extension(file: UploadFile, valid_exts: list[str]) -> bool:
  _, ext = os.path.splitext(file.filename)
  return ext.lower() in valid_exts
