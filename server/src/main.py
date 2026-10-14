from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.requests import Request
from fastapi.staticfiles import StaticFiles
import traceback

from src.database import init_db
from src.api import router

app = FastAPI(title="AudioLoca")

app.add_middleware(
  CORSMiddleware,
  allow_origins=["http://localhost:8100", "http://127.0.0.1:8100", "http://192.168.1.22:8100"],
  allow_credentials=True,
  allow_methods=["OPTIONS", "POST", "GET", "DELETE", "PATCH", "PUT"],
  allow_headers=["Content-Type", "Authorization"]
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
  print(f"Incoming Request: {request.method} {request.url}")
  response = await call_next(request)
  print(f"Response Headers: {response.headers}")
  return response

from fastapi import HTTPException
from fastapi.exceptions import RequestValidationError

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
  detail_msg = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
  return JSONResponse(
    status_code=exc.status_code,
    content={"message": detail_msg, "detail": detail_msg},
  )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
  errors = exc.errors()
  if errors:
    first_err = errors[0]
    loc = " -> ".join([str(x) for x in first_err.get("loc", []) if x != "body"])
    msg = first_err.get("msg", "Invalid input parameter")
    clean_msg = f"{loc}: {msg}" if loc else msg
  else:
    clean_msg = "Invalid request format."
  return JSONResponse(
    status_code=422,
    content={"message": clean_msg, "detail": clean_msg},
  )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
  print("Unhandled exception:", traceback.format_exc())
  return JSONResponse(
    status_code=500,
    content={
      "message": "An unexpected server error occurred. Please try again.",
      "detail": "An unexpected server error occurred. Please try again.",
    },
  )

@app.post("/debug/headers")
async def debug_headers(request: Request):
  print("Headers:", request.headers)
  return {"headers": dict(request.headers)}

app.mount("/media", StaticFiles(directory="./media"), name="media")

# Initialize Database
@app.on_event("startup")
def on_startup():
  init_db()

# Routers
app.include_router(router)
