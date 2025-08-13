from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from src.database import init_db
from src.api import router

app = FastAPI(title='AudioLoca')

app.add_middleware(
  CORSMiddleware,
  allow_origins=['http://localhost:8100', 'http://127.0.0.1:8000:8100', 'http://192.168.29.30:8100'],
  allow_credentials=True,
  allow_methods=['OPTIONS', 'POST', 'GET', 'DELETE', 'PATCH', 'PUT'],
  allow_headers=['Content-Type', 'Authorization']
)

@app.middleware('http')
async def log_requests(request: Request, call_next):
  print(f'Incoming Request: {request.method} {request.url}')
  response = await call_next(request)
  print(f'Response Headers: {response.headers}')
  return response

app.mount("/media", StaticFiles(directory="./media"), name="media")

# Initialize Database
@app.on_event('startup')
def on_startup():
  init_db()

# Routers
app.include_router(router)
