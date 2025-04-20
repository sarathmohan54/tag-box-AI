from fastapi import FastAPI, HTTPException, Depends, status, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
import models
import database
from pydantic import BaseModel, EmailStr, validator
from typing import Optional, List, Dict, Any
import time
import sqlalchemy.exc
import re
import logging
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
import os
import requests
from urllib.parse import quote_plus, quote
from base64 import b64encode
import aiohttp
import asyncio
import json
import urllib.parse
from bs4 import BeautifulSoup

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Set uvicorn access logger level to warning to reduce noise
uvicorn_access = logging.getLogger("uvicorn.access")
uvicorn_access.setLevel(logging.WARNING)

# Wait for database to be ready
max_retries = 30
retries = 0
while retries < max_retries:
    try:
        # Try to connect to the database
        database.engine.connect()
        # Initialize database
        database.init_db()
        break
    except sqlalchemy.exc.OperationalError:
        retries += 1
        print(f"Waiting for database... {retries}/{max_retries}")
        time.sleep(1)
    except Exception as e:
        print(f"Error initializing database: {e}")
        break

# Secret key for JWT
SECRET_KEY = os.getenv("SECRET_KEY", "your_secret_key")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "43200"))

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Create FastAPI app
app = FastAPI()

# Create API router
router = APIRouter()

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Dependency to get the database session
def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

# OAuth2 scheme for token authentication
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/login")

# Define a Pydantic model for the user registration request
class UserCreate(BaseModel):
    email: EmailStr
    password: str

    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not re.search(r'[A-Z]', v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not re.search(r'[a-z]', v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not re.search(r'[0-9]', v):
            raise ValueError('Password must contain at least one number')
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "email": "user@example.com",
                "password": "strongPassword123"
            }
        }

# Define a Pydantic model for the login request
class LoginRequest(BaseModel):
    email: EmailStr
    password: str

    class Config:
        json_schema_extra = {
            "example": {
                "email": "user@example.com",
                "password": "strongPassword123"
            }
        }

# Define a Pydantic model for the token response
class Token(BaseModel):
    access_token: str
    token_type: str

# Define a Pydantic model for the password change request
class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str

    @validator('new_password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not re.search(r'[A-Z]', v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not re.search(r'[a-z]', v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not re.search(r'[0-9]', v):
            raise ValueError('Password must contain at least one number')
        return v

# Utility function to hash passwords
def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

# Utility function to verify passwords
def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

# Utility function to create access tokens
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# Utility function to get current user from token
async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    return user

@router.get("/")
async def root():
    return {"message": "Welcome to the FastAPI backend!"}

@router.post("/api/register")
async def register(user: UserCreate, db: Session = Depends(get_db)):
    try:
        # Check if user already exists
        logger.debug(f"Checking if user exists: {user.email}")
        db_user = db.query(models.User).filter(models.User.email == user.email).first()
        if db_user:
            logger.debug(f"User already exists: {user.email}")
            return JSONResponse(
                status_code=400,
                content={"detail": "Email already registered"}
            )
        
        # Hash the password and create a new user
        logger.debug("Hashing password")
        hashed_password = get_password_hash(user.password)
        logger.debug("Creating new user")
        new_user = models.User(email=user.email, hashed_password=hashed_password)
        logger.debug("Adding user to database")
        db.add(new_user)
        logger.debug("Committing transaction")
        db.commit()
        logger.debug("Refreshing user object")
        db.refresh(new_user)
        
        # Create a token for the new user
        logger.debug("Creating access token")
        access_token = create_access_token(
            data={"sub": new_user.email},
            expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        )
        return {"access_token": access_token, "token_type": "bearer"}
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        logger.error(f"Error during registration: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while registering: {str(e)}"
        )

@router.post("/api/login")
async def login(user_login: LoginRequest, db: Session = Depends(get_db)):
    try:
        # Authenticate user
        user = db.query(models.User).filter(models.User.email == user_login.email).first()
        if not user:
            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )
        
        if not verify_password(user_login.password, user.hashed_password):
            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )
        
        # Create a token for the authenticated user
        access_token = create_access_token(
            data={"sub": user.email},
            expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        )
        return {"access_token": access_token, "token_type": "bearer"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while logging in: {str(e)}"
        )

@router.post("/api/change-password")
async def change_password(
    request: PasswordChangeRequest,
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    try:
        logger.debug(f"Received password change request")
        
        # Decode the token and get user
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            email = payload.get("sub")
            if email is None:
                raise HTTPException(
                    status_code=401,
                    detail="Invalid authentication credentials"
                )
            logger.debug(f"Token decoded successfully for user: {email}")
        except JWTError as e:
            logger.error(f"Token validation error: {str(e)}")
            raise HTTPException(
                status_code=401,
                detail="Could not validate credentials"
            )
        
        # Get user from database
        current_user = db.query(models.User).filter(models.User.email == email).first()
        if current_user is None:
            logger.error(f"User not found: {email}")
            raise HTTPException(
                status_code=404,
                detail="User not found"
            )
        
        logger.debug("Verifying current password")
        # Verify current password
        if not verify_password(request.current_password, current_user.hashed_password):
            logger.error("Current password verification failed")
            raise HTTPException(
                status_code=400,
                detail="Current password is incorrect"
            )
        
        logger.debug("Hashing new password")
        # Hash new password and update
        hashed_password = get_password_hash(request.new_password)
        current_user.hashed_password = hashed_password
        db.commit()
        logger.debug("Password updated successfully")
        
        return {"message": "Password changed successfully"}
    except HTTPException:
        raise
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error during password change: {str(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while changing password: {str(e)}"
        )

@router.post("/api/refresh-token")
async def refresh_token(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        # Verify the current token
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email = payload.get("sub")
        if email is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid token"
            )
        
        # Check if user exists
        user = db.query(models.User).filter(models.User.email == email).first()
        if user is None:
            raise HTTPException(
                status_code=401,
                detail="User not found"
            )
        
        # Create new token
        access_token = create_access_token(
            data={"sub": email},
            expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        )
        
        return {"access_token": access_token, "token_type": "bearer"}
    except JWTError:
        raise HTTPException(
            status_code=401,
            detail="Invalid token"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while refreshing token: {str(e)}"
        )

# Define Pydantic models for categories and tags
class CategoryCreate(BaseModel):
    name: str

class CategoryResponse(BaseModel):
    id: int
    name: str
    created_at: datetime

    class Config:
        from_attributes = True

class TagCreate(BaseModel):
    name: str

class TagResponse(BaseModel):
    id: int
    name: str
    created_at: datetime

    class Config:
        from_attributes = True

# Update ReelCreate model to include category and tags
class ReelCreate(BaseModel):
    platform: str
    reel_id: str
    url: str
    thumbnail_url: str
    caption: str
    author: str
    category_ids: list[int] = []
    tags: list[str] = []
    reel_metadata: dict = {}

    class Config:
        json_schema_extra = {
            "example": {
                "platform": "instagram",
                "reel_id": "123456789",
                "url": "https://www.instagram.com/reel/123456789",
                "thumbnail_url": "https://example.com/thumbnail.jpg",
                "caption": "Amazing video!",
                "author": "@creator",
                "category_ids": [1, 2],
                "tags": ["funny", "dance"],
                "reel_metadata": {
                    "likes": 1000,
                    "views": 5000,
                    "duration": "00:30"
                }
            }
        }

# Update ReelResponse model to include category and tags
class ReelResponse(BaseModel):
    id: int
    platform: str
    reel_id: str
    url: str
    thumbnail_url: str
    caption: str
    author: str
    created_at: datetime
    categories: list[CategoryResponse]
    tags: list[TagResponse] = []
    reel_metadata: dict
    is_synced: bool

    class Config:
        from_attributes = True

# Category endpoints
@router.post("/api/categories", response_model=CategoryResponse)
async def create_category(
    category: CategoryCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Check if category already exists for this user
        existing_category = db.query(models.Category).filter(
            models.Category.user_id == current_user.id,
            models.Category.name == category.name
        ).first()
        
        if existing_category:
            raise HTTPException(
                status_code=400,
                detail="Category already exists"
            )
        
        db_category = models.Category(
            name=category.name,
            user_id=current_user.id
        )
        
        db.add(db_category)
        db.commit()
        db.refresh(db_category)
        
        return db_category
        
    except Exception as e:
        logger.error(f"Error creating category: {str(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while creating the category: {str(e)}"
        )

@router.get("/api/categories", response_model=list[CategoryResponse])
async def get_categories(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        categories = db.query(models.Category)\
            .filter(models.Category.user_id == current_user.id)\
            .order_by(models.Category.name)\
            .all()
            
        return categories
        
    except Exception as e:
        logger.error(f"Error fetching categories: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while fetching categories: {str(e)}"
        )

@router.delete("/api/categories/{category_id}")
async def delete_category(
    category_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        category = db.query(models.Category)\
            .filter(
                models.Category.id == category_id,
                models.Category.user_id == current_user.id
            )\
            .first()
            
        if not category:
            raise HTTPException(
                status_code=404,
                detail="Category not found"
            )
            
        # Update reels to remove category reference
        db.query(models.Reel)\
            .filter(models.Reel.category_id == category_id)\
            .update({models.Reel.category_id: None})
            
        db.delete(category)
        db.commit()
        
        return {"message": "Category deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting category: {str(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while deleting the category: {str(e)}"
        )

# Tag endpoints
@router.post("/api/tags", response_model=TagResponse)
async def create_tag(
    tag: TagCreate,
    db: Session = Depends(get_db)
):
    try:
        # Check if tag already exists
        existing_tag = db.query(models.Tag)\
            .filter(models.Tag.name == tag.name)\
            .first()
            
        if existing_tag:
            return existing_tag
        
        db_tag = models.Tag(name=tag.name)
        db.add(db_tag)
        db.commit()
        db.refresh(db_tag)
        
        return db_tag
        
    except Exception as e:
        logger.error(f"Error creating tag: {str(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while creating the tag: {str(e)}"
        )

@router.get("/api/tags", response_model=list[TagResponse])
async def get_tags(
    search: Optional[str] = None,
    db: Session = Depends(get_db)
):
    try:
        query = db.query(models.Tag)
        if search:
            query = query.filter(models.Tag.name.ilike(f"%{search}%"))
        tags = query.order_by(models.Tag.name).all()
        return tags
        
    except Exception as e:
        logger.error(f"Error fetching tags: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while fetching tags: {str(e)}"
        )

# Update reel endpoints to handle categories and tags
@router.post("/api/reels", response_model=ReelResponse)
async def create_reel(
    reel: ReelCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Check if reel already exists
        existing_reel = db.query(models.Reel).filter(
            models.Reel.user_id == current_user.id,
            models.Reel.reel_id == reel.reel_id,
            models.Reel.platform == reel.platform
        ).first()
        
        if existing_reel:
            # Instead of error, return the existing reel with a different status code
            logger.info(f"Reel already exists, returning existing reel: {existing_reel.id}")
            return JSONResponse(
                status_code=200,  # Change to 200 OK instead of error
                content={
                    "id": existing_reel.id,
                    "platform": existing_reel.platform,
                    "reel_id": existing_reel.reel_id,
                    "url": existing_reel.url,
                    "thumbnail_url": existing_reel.thumbnail_url,
                    "caption": existing_reel.caption,
                    "author": existing_reel.author,
                    "created_at": existing_reel.created_at.isoformat(),
                    "reel_metadata": existing_reel.reel_metadata,
                    "is_synced": existing_reel.is_synced,
                    "categories": [{"id": c.id, "name": c.name, "created_at": c.created_at.isoformat()} for c in existing_reel.categories],
                    "tags": [{"id": t.id, "name": t.name, "created_at": t.created_at.isoformat()} for t in existing_reel.tags],
                    "message": "This reel was already saved in your collection"
                }
            )
        
        # Verify categories belong to user
        categories = []
        for category_id in reel.category_ids:
            category = db.query(models.Category).filter(
                models.Category.id == category_id,
                models.Category.user_id == current_user.id
            ).first()
            
            if not category:
                raise HTTPException(
                    status_code=404,
                    detail=f"Category {category_id} not found"
                )
            categories.append(category)
        
        # Create or get tags
        tag_objects = []
        for tag_name in reel.tags:
            tag = db.query(models.Tag).filter(models.Tag.name == tag_name).first()
            if not tag:
                tag = models.Tag(name=tag_name)
                db.add(tag)
            tag_objects.append(tag)
        
        # Create new reel
        db_reel = models.Reel(
            user_id=current_user.id,
            platform=reel.platform,
            reel_id=reel.reel_id,
            url=reel.url,
            thumbnail_url=reel.thumbnail_url,
            caption=reel.caption,
            author=reel.author,
            reel_metadata=reel.reel_metadata,
            tags=tag_objects,
            categories=categories
        )
        
        db.add(db_reel)
        db.commit()
        db.refresh(db_reel)
        
        return db_reel
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating reel: {str(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while saving the reel: {str(e)}"
        )

@router.get("/api/reels", response_model=list[ReelResponse])
async def get_user_reels(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 20,
    search: Optional[str] = None,
    category_id: Optional[int] = None,
    category_ids: Optional[str] = None,
    tag: Optional[str] = None,
    platform: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
):
    try:
        query = db.query(models.Reel)\
            .filter(models.Reel.user_id == current_user.id)
            
        # Apply filters
        if search:
            query = query.filter(
                models.Reel.caption.ilike(f"%{search}%") |
                models.Reel.author.ilike(f"%{search}%")
            )
            
        if category_ids:
            # Parse comma-separated category IDs
            ids = [int(id) for id in category_ids.split(',')]
            # Filter reels that have any of the specified categories
            query = query.join(models.Reel.categories)\
                .filter(models.Category.id.in_(ids))
        elif category_id:  # Fallback to single category filter
            query = query.join(models.Reel.categories)\
                .filter(models.Category.id == category_id)
            
        if tag:
            query = query.join(models.Reel.tags)\
                .filter(models.Tag.name == tag)
                
        if platform:
            query = query.filter(models.Reel.platform == platform)
            
        # Date range filtering
        if start_date:
            try:
                start_datetime = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
                query = query.filter(models.Reel.created_at >= start_datetime)
            except ValueError as e:
                logger.error(f"Invalid start_date format: {e}")
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid start_date format. Use ISO format (YYYY-MM-DDThh:mm:ss.sssZ)"
                )
                
        if end_date:
            try:
                end_datetime = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
                query = query.filter(models.Reel.created_at <= end_datetime)
            except ValueError as e:
                logger.error(f"Invalid end_date format: {e}")
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid end_date format. Use ISO format (YYYY-MM-DDThh:mm:ss.sssZ)"
                )
            
        reels = query\
            .order_by(models.Reel.created_at.desc())\
            .offset(skip)\
            .limit(limit)\
            .all()
            
        return reels
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching reels: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while fetching reels: {str(e)}"
        )

@router.delete("/api/reels/{reel_id}")
async def delete_reel(
    reel_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        logger.debug(f"Deleting reel {reel_id} for user {current_user.email}")
        
        reel = db.query(models.Reel)\
            .filter(models.Reel.id == reel_id, models.Reel.user_id == current_user.id)\
            .first()
            
        if not reel:
            raise HTTPException(
                status_code=404,
                detail="Reel not found"
            )
            
        db.delete(reel)
        db.commit()
        
        return {"message": "Reel deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting reel: {str(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while deleting the reel: {str(e)}"
        )

# Define a model for reel extraction request
class ReelExtractionRequest(BaseModel):
    url: str

    class Config:
        json_schema_extra = {
            "example": {
                "url": "https://www.facebook.com/share/r/123456789"
            }
        }

# Facebook API Configuration
FACEBOOK_APP_ID = os.getenv("FACEBOOK_APP_ID", "")
FACEBOOK_APP_SECRET = os.getenv("FACEBOOK_APP_SECRET", "")
FACEBOOK_ACCESS_TOKEN = os.getenv("FACEBOOK_ACCESS_TOKEN", "")

def get_facebook_access_token():
    """Get a Facebook access token from environment variables."""
    return os.getenv("FACEBOOK_ACCESS_TOKEN")

def get_video_id_from_url(url):
    """Extract video ID from various Facebook URL formats."""
    patterns = [
        r'facebook\.com/.*?/videos/(\d+)',
        r'facebook\.com/watch/\?v=(\d+)',
        r'fb\.watch/(\w+)',
        r'/share/r/(\w+)',
        r'/share/v/(\w+)',
        r'/reel/(\d+)',
    ]
    
    logger.debug(f"Attempting to extract video ID from URL: {url}")
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            video_id = match.group(1)
            logger.debug(f"Found video ID {video_id} using pattern {pattern}")
            return video_id
    logger.debug("No video ID found in URL")
    return None

async def extract_facebook_info(url: str) -> Dict[str, Any]:
    """Extract basic metadata from Facebook URLs."""
    logger.info(f"Extracting Facebook info from URL: {url}")
    
    try:
        # Extract video ID
        video_id = get_video_id_from_url(url)
        
        if not video_id:
            logger.error("Could not extract video ID from URL")
            raise ValueError("Could not extract video ID from URL")
            
        # Generate URLs
        watch_url = f"https://www.facebook.com/watch?v={video_id}"
        encoded_watch_url = quote_plus(watch_url)
        embed_url = f"https://www.facebook.com/plugins/video.php?href={encoded_watch_url}&show_text=false"
        
        return {
            'platform': 'facebook',
            'reel_id': video_id,
            'url': watch_url,
            'thumbnail_url': f'https://placehold.co/600x800/3B5998/FFFFFF.png?text=Facebook+Video:+{video_id}',
            'embed_url': embed_url,
            'caption': 'Facebook Video',
            'author': '@facebook_user',
            'metadata': {
                'original_url': url,
                'final_url': watch_url,
                'video_id': video_id,
                'embed_url': embed_url,
                'webview_enabled': True,
                'extracted_at': datetime.utcnow().isoformat()
            }
        }
    except Exception as e:
        logger.error(f"Error extracting Facebook info: {str(e)}")
        raise

async def enhanced_extract_facebook_info(url: str) -> Dict[str, Any]:
    """Enhanced version of Facebook info extraction with WebView support."""
    logger.info(f"Extracting enhanced Facebook info from URL: {url}")
    
    try:
        # Get the basic info first
        basic_info = await extract_facebook_info(url)
        video_id = basic_info['reel_id']
        
        # Set up WebView URLs and properties
        watch_url = f"https://www.facebook.com/watch?v={video_id}"
        encoded_watch_url = quote_plus(watch_url)
        embed_url = f"https://www.facebook.com/plugins/video.php?href={encoded_watch_url}&show_text=false&t=0"

        # Provide multiple embed URLs for fallback
        embed_urls = [
            embed_url,
            f"https://www.facebook.com/plugins/post.php?href={encoded_watch_url}&show_text=true", 
            f"https://www.facebook.com/plugins/video.php?href={encoded_watch_url}&show_text=true"
        ]
        
        # WebView metadata with performance optimizations
        enhanced_metadata = {
            **basic_info['metadata'],
            'title': 'Facebook Video',
            'embed_urls': embed_urls,
            'webview_enabled': True,
            'webview_settings': {
                'javascript_enabled': True,
                'dom_storage_enabled': True,
                'support_zoom': False,
                'cache_enabled': True,
                'media_playback_requires_user_gesture': False
            }
        }
        
        # Return enhanced result
        return {
            **basic_info,
            'embed_url': embed_url,
            'embed_urls': embed_urls,
            'metadata': enhanced_metadata
        }
        
    except Exception as e:
        logger.error(f"Error in enhanced_extract_facebook_info: {str(e)}")
        # Fall back to the original implementation
        try:
            return await extract_facebook_info(url)
        except Exception as fallback_e:
            logger.error(f"Fallback also failed: {str(fallback_e)}")
            raise

async def extract_tags_from_text(text: str) -> List[str]:
    """Extract hashtags from text content"""
    if not text:
        return []
    
    # Look for hashtags using regex
    hashtag_pattern = r'#(\w+)'
    hashtags = re.findall(hashtag_pattern, text)
    
    # Convert to lowercase and remove duplicates
    unique_tags = list(set([tag.lower() for tag in hashtags]))
    
    # Limit to reasonable number of tags
    return unique_tags[:10]  # Return max 10 tags
    
async def extract_youtube_metadata(video_id: str) -> Dict[str, Any]:
    """Extract metadata from YouTube videos"""
    logger.info(f"Extracting YouTube metadata for video ID: {video_id}")
    
    try:
        # Fetch the oEmbed data which is public and doesn't require API key
        oembed_url = f"https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v={video_id}&format=json"
        
        async with aiohttp.ClientSession() as session:
            async with session.get(oembed_url) as response:
                if response.status == 200:
                    oembed_data = await response.json()
                    logger.debug(f"YouTube oEmbed data: {oembed_data}")
                    
                    # Extract metadata from oembed
                    title = oembed_data.get('title', '')
                    author = oembed_data.get('author_name', '@youtube_user')
                    
                    # Also try to fetch the actual page to extract more metadata
                    page_url = f"https://www.youtube.com/watch?v={video_id}"
                    
                    async with session.get(page_url) as page_response:
                        if page_response.status == 200:
                            html = await page_response.text()
                            soup = BeautifulSoup(html, 'html.parser')
                            
                            # Try to extract description
                            description = ""
                            for meta in soup.find_all('meta'):
                                if meta.get('name') == 'description':
                                    description = meta.get('content', '')
                                    break
                            
                            # Extract tags from description and title
                            tags = await extract_tags_from_text(title + " " + description)
                            
                            return {
                                'platform': 'youtube',
                                'reel_id': video_id,
                                'url': page_url,
                                'thumbnail_url': f'https://img.youtube.com/vi/{video_id}/maxresdefault.jpg',
                                'caption': title,
                                'author': author,
                                'metadata': {
                                    'video_id': video_id,
                                    'title': title,
                                    'description': description,
                                    'author_name': author,
                                    'thumbnail_urls': [
                                        f'https://img.youtube.com/vi/{video_id}/maxresdefault.jpg',
                                        f'https://img.youtube.com/vi/{video_id}/hqdefault.jpg',
                                        f'https://img.youtube.com/vi/{video_id}/mqdefault.jpg',
                                    ],
                                    'tags': tags,
                                    'extracted_at': datetime.utcnow().isoformat()
                                }
                            }
                
                # Fallback to basic info if oEmbed fails
                return {
                    'platform': 'youtube',
                    'reel_id': video_id,
                    'url': f'https://www.youtube.com/watch?v={video_id}',
                    'thumbnail_url': f'https://img.youtube.com/vi/{video_id}/maxresdefault.jpg',
                    'caption': 'YouTube Video',
                    'author': '@youtube_user',
                    'metadata': {
                        'video_id': video_id,
                        'thumbnail_urls': [
                            f'https://img.youtube.com/vi/{video_id}/maxresdefault.jpg',
                            f'https://img.youtube.com/vi/{video_id}/hqdefault.jpg',
                        ],
                        'extracted_at': datetime.utcnow().isoformat()
                    }
                }
    except Exception as e:
        logger.error(f"Error extracting YouTube metadata: {str(e)}")
        # Return basic info on error
        return {
            'platform': 'youtube',
            'reel_id': video_id,
            'url': f'https://www.youtube.com/watch?v={video_id}',
            'thumbnail_url': f'https://img.youtube.com/vi/{video_id}/maxresdefault.jpg',
            'caption': 'YouTube Video',
            'author': '@youtube_user',
            'metadata': {
                'video_id': video_id,
                'extracted_at': datetime.utcnow().isoformat()
            }
        }

async def extract_tiktok_metadata(video_id: str, url: str) -> Dict[str, Any]:
    """Extract metadata from TikTok videos"""
    logger.info(f"Extracting TikTok metadata for video ID: {video_id}")
    
    try:
        # TikTok metadata is harder to get, try to scrape the page
        async with aiohttp.ClientSession() as session:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
            
            async with session.get(url, headers=headers) as response:
                if response.status == 200:
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')
                    
                    # Try to extract title/caption
                    caption = "TikTok Video"
                    author = "@tiktok_user"
                    
                    # Look for meta tags
                    for meta in soup.find_all('meta'):
                        if meta.get('property') == 'og:title':
                            caption = meta.get('content', caption)
                        if meta.get('name') == 'author':
                            author = meta.get('content', author)
                        if meta.get('property') == 'og:description':
                            description = meta.get('content', '')
                            
                    # Extract hashtags from caption and description
                    tags = await extract_tags_from_text(caption + " " + description if 'description' in locals() else caption)
                    
                    # Look for thumbnail URL
                    thumbnail_url = None
                    for meta in soup.find_all('meta'):
                        if meta.get('property') == 'og:image':
                            thumbnail_url = meta.get('content')
                            break
                    
                    return {
                        'platform': 'tiktok',
                        'reel_id': video_id,
                        'url': url,
                        'thumbnail_url': thumbnail_url or f'https://placehold.co/300x400/808080/FFFFFF.png?text=TikTok+Video',
                        'caption': caption,
                        'author': author,
                        'metadata': {
                            'video_id': video_id,
                            'title': caption,
                            'author_name': author,
                            'description': description if 'description' in locals() else '',
                            'thumbnail_url': thumbnail_url,
                            'tags': tags,
                            'extracted_at': datetime.utcnow().isoformat()
                        }
                    }
    
    except Exception as e:
        logger.error(f"Error extracting TikTok metadata: {str(e)}")
    
    # Return basic info on error
    return {
        'platform': 'tiktok',
        'reel_id': video_id,
        'url': url,
        'thumbnail_url': f'https://placehold.co/300x400/808080/FFFFFF.png?text=TikTok+Video',
        'caption': 'TikTok Video',
        'author': '@tiktok_user',
        'metadata': {
            'video_id': video_id,
            'extracted_at': datetime.utcnow().isoformat()
        }
    }

async def extract_instagram_metadata(reel_id: str, url: str) -> Dict[str, Any]:
    """Extract metadata from Instagram posts/reels with WebView support."""
    logger.info(f"Extracting Instagram metadata for reel ID: {reel_id}")
    
    try:
        # Determine if it's a reel or post
        is_reel = '/reel/' in url
        is_post = '/p/' in url
        
        # Create embed URL for WebView
        embed_url = f"https://www.instagram.com/{'reel' if is_reel else 'p'}/{reel_id}/embed/"
        oEmbed_url = f"https://api.instagram.com/oembed/?url={quote_plus(url)}"
        
        # Create a list of possible embed URLs to try
        embed_urls = [
            embed_url,
            f"https://www.instagram.com/p/{reel_id}/embed/",
            f"https://www.instagram.com/reel/{reel_id}/embed/",
            url  # Original URL as fallback
        ]
        
        # Create Instagram gradient color thumbnail
        gradient_thumbnail = f'https://placehold.co/600x800/C13584,E1306C,F77737/FFFFFF.png?text=Instagram+{"Reel" if is_reel else "Post"}:+{reel_id}'
        
        # Return structured data for WebView
        return {
            'platform': 'instagram',
            'reel_id': reel_id,
            'url': url,
            'thumbnail_url': gradient_thumbnail,
            'embed_url': embed_url,
            'embed_urls': embed_urls,
            'caption': 'Instagram Reel' if is_reel else 'Instagram Post',
            'author': '@instagram_user',
            'metadata': {
                'reel_id': reel_id,
                'type': 'reel' if is_reel else 'post',
                'embed_url': embed_url,
                'embed_urls': embed_urls,
                'webview_enabled': True,
                'webview_settings': {
                    'javascript_enabled': True,
                    'dom_storage_enabled': True,
                    'support_zoom': False,
                    'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                    'cache_enabled': True
                },
                'extracted_at': datetime.utcnow().isoformat()
            }
        }
    except Exception as e:
        logger.error(f"Error extracting Instagram metadata: {str(e)}")
    
    # Return basic info on error
    return {
        'platform': 'instagram',
        'reel_id': reel_id,
        'url': url,
        'thumbnail_url': f'https://placehold.co/600x800/C13584,E1306C,F77737/FFFFFF.png?text=Instagram+Media',
        'embed_url': url,
        'caption': 'Instagram Media',
        'author': '@instagram_user',
        'metadata': {
            'reel_id': reel_id,
            'webview_enabled': True,
            'extracted_at': datetime.utcnow().isoformat()
        }
    }

@router.post("/api/extract-reel-info")
async def extract_reel_info(
    request: ReelExtractionRequest,
    current_user: models.User = Depends(get_current_user),
):
    try:
        url = request.url.strip()
        logger.info(f"Extracting info from URL: {url}")

        # Initialize default response
        result = {
            'platform': None,
            'reel_id': None,
            'url': url,
            'thumbnail_url': None,
            'caption': None,
            'author': None,
            'metadata': {
                'original_url': url,
                'extracted_at': datetime.utcnow().isoformat()
            }
        }

        # Facebook URL handling
        if 'facebook.com' in url or 'fb.watch' in url:
            # Use enhanced Facebook extraction
            facebook_result = await enhanced_extract_facebook_info(url)
            result.update(facebook_result)
            return result

        # Instagram URL handling
        elif 'instagram.com' in url:
            logger.debug('Processing Instagram URL')
            reel_id = None
            
            if '/reel/' in url:
                reel_id = url.split('/reel/')[1].split('/')[0].split('?')[0]
            elif '/p/' in url:
                reel_id = url.split('/p/')[1].split('/')[0].split('?')[0]
            
            if reel_id:
                # Use enhanced Instagram extraction
                instagram_result = await extract_instagram_metadata(reel_id, url)
                result.update(instagram_result)
                return result
                
            # Fall back to basic info if reel_id not found
            result.update({
                'platform': 'instagram',
                'reel_id': 'unknown',
                'thumbnail_url': f'https://placehold.co/300x400/808080/FFFFFF.png?text=Instagram+Video',
                'caption': 'Instagram Video',
                'author': '@instagram_user'
            })

        # TikTok URL handling
        elif 'tiktok.com' in url:
            logger.debug('Processing TikTok URL')
            video_id = None
            
            if '/video/' in url:
                video_id = url.split('/video/')[1].split('/')[0].split('?')[0]
            
            if video_id:
                # Use enhanced TikTok extraction
                tiktok_result = await extract_tiktok_metadata(video_id, url)
                result.update(tiktok_result)
                return result
                
            # Fall back to basic info if video_id not found
            result.update({
                'platform': 'tiktok',
                'reel_id': 'unknown',
                'thumbnail_url': f'https://placehold.co/300x400/808080/FFFFFF.png?text=TikTok+Video',
                'caption': 'TikTok Video',
                'author': '@tiktok_user'
            })

        # YouTube URL handling
        elif 'youtube.com' in url or 'youtu.be' in url:
            logger.debug('Processing YouTube URL')
            video_id = None
            
            if 'youtu.be/' in url:
                video_id = url.split('youtu.be/')[1].split('?')[0]
            elif 'youtube.com/watch' in url:
                video_id = url.split('v=')[1].split('&')[0]
            elif 'youtube.com/shorts/' in url:
                video_id = url.split('shorts/')[1].split('?')[0]
            
            if video_id:
                # Use enhanced YouTube extraction
                youtube_result = await extract_youtube_metadata(video_id)
                result.update(youtube_result)
                return result
                
            # Fall back to basic info if video_id not found
            result.update({
                'platform': 'youtube',
                'reel_id': 'unknown',
                'thumbnail_url': f'https://placehold.co/300x400/808080/FFFFFF.png?text=YouTube+Video',
                'caption': 'YouTube Video',
                'author': '@youtube_user'
            })

        if not result['platform']:
            logger.error(f"Unsupported URL format: {url}")
            raise HTTPException(
                status_code=400,
                detail="Unsupported URL format or could not extract video information"
            )

        logger.debug(f"Extracted info: {result}")
        return result

    except Exception as e:
        logger.error(f"Error extracting reel info: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while extracting reel information: {str(e)}"
        )

# Include router in app
app.include_router(router)

def update_placeholder_urls(db: Session):
    try:
        # Get all Facebook reels
        facebook_reels = db.query(models.Reel).filter(
            models.Reel.platform == 'facebook'
        ).all()
        
        # Update each Facebook reel with proper embed URL
        for reel in facebook_reels:
            try:
                # Extract original URL from metadata if available
                original_url = reel.reel_metadata.get('original_url', reel.url)
                encoded_url = quote_plus(original_url)
                embed_url = f"https://www.facebook.com/plugins/video.php?href={encoded_url}&show_text=false&t=0"
                
                # Update the reel
                reel.thumbnail_url = embed_url
                reel.reel_metadata = {
                    **reel.reel_metadata,
                    'embed_url': embed_url,
                    'embed_html': f'<iframe src="{embed_url}" width="100%" height="100%" style="border:none;overflow:hidden" scrolling="no" frameborder="0" allowfullscreen="true" allow="autoplay; clipboard-write; encrypted-media; picture-in-picture; web-share"></iframe>'
                }
            except Exception as e:
                logger.error(f'Error updating Facebook reel {reel.id}: {e}')
                continue

        # Update other platform placeholders if needed
        db.query(models.Reel).filter(
            models.Reel.platform == 'instagram',
            models.Reel.thumbnail_url.like('%placeholder%')
        ).update({
            'thumbnail_url': 'https://placehold.co/300x400/808080/FFFFFF.png?text=Instagram+Video'
        })

        db.query(models.Reel).filter(
            models.Reel.platform == 'tiktok',
            models.Reel.thumbnail_url.like('%placeholder%')
        ).update({
            'thumbnail_url': 'https://placehold.co/300x400/808080/FFFFFF.png?text=TikTok+Video'
        })

        # Update any remaining reels with placeholder URLs
        db.query(models.Reel).filter(
            models.Reel.thumbnail_url.like('%placeholder%')
        ).update({
            'thumbnail_url': 'https://placehold.co/300x400/808080/FFFFFF.png?text=Video'
        })

        db.commit()
        logger.debug('Updated placeholder URLs in existing reels')
    except Exception as e:
        logger.error(f'Error updating placeholder URLs: {e}')
        db.rollback()

# Call this function after database initialization
database.init_db()
with database.SessionLocal() as db:
    update_placeholder_urls(db) 