from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime, JSON, Table
from sqlalchemy.orm import relationship
from database import Base
import datetime

# Association table for reel tags
reel_tags = Table(
    'reel_tags',
    Base.metadata,
    Column('reel_id', Integer, ForeignKey('reels.id')),
    Column('tag_id', Integer, ForeignKey('tags.id'))
)

# Association table for reel categories
reel_categories = Table(
    'reel_categories',
    Base.metadata,
    Column('reel_id', Integer, ForeignKey('reels.id')),
    Column('category_id', Integer, ForeignKey('categories.id'))
)

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)
    reels = relationship("Reel", back_populates="user")
    categories = relationship("Category", back_populates="user")

class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    user_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="categories")
    reels = relationship("Reel", secondary=reel_categories, back_populates="categories")

class Tag(Base):
    __tablename__ = "tags"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    reels = relationship("Reel", secondary=reel_tags, back_populates="tags")

class Reel(Base):
    __tablename__ = "reels"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    platform = Column(String)  # e.g., "instagram", "tiktok", etc.
    reel_id = Column(String, index=True)  # Original reel ID from the platform
    url = Column(String)
    thumbnail_url = Column(String)
    caption = Column(String)
    author = Column(String)  # Original content creator
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    reel_metadata = Column(JSON)  # Store additional platform-specific data
    is_synced = Column(Boolean, default=True)  # For offline support
    
    user = relationship("User", back_populates="reels")
    categories = relationship("Category", secondary=reel_categories, back_populates="reels")
    tags = relationship("Tag", secondary=reel_tags, back_populates="reels") 