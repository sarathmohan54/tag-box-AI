import os
os.environ["TESTING"] = "true"

from fastapi.testclient import TestClient
from main import app
from database import Base, engine
import json

# Set up the database for testing
Base.metadata.create_all(bind=engine)

client = TestClient(app)

def test_register_user():
    # Test user registration
    user_data = {
        "email": "test@example.com",
        "password": "TestPassword123"
    }
    response = client.post("/api/register", json=user_data)
    assert response.status_code == 200
    assert "access_token" in response.json()
    assert response.json()["token_type"] == "bearer"

def test_login_user():
    # Test user login
    login_data = {
        "email": "test@example.com",
        "password": "TestPassword123"
    }
    response = client.post("/api/login", json=login_data)
    assert response.status_code == 200
    assert "access_token" in response.json()
    assert response.json()["token_type"] == "bearer"

def test_create_category():
    # First login to get token
    login_data = {
        "email": "test@example.com",
        "password": "TestPassword123"
    }
    login_response = client.post("/api/login", json=login_data)
    token = login_response.json()["access_token"]
    
    # Test category creation
    headers = {"Authorization": f"Bearer {token}"}
    category_data = {"name": "Test Category"}
    response = client.post("/api/categories", json=category_data, headers=headers)
    assert response.status_code == 200
    assert response.json()["name"] == "Test Category"

def test_create_reel():
    # First login to get token
    login_data = {
        "email": "test@example.com",
        "password": "TestPassword123"
    }
    login_response = client.post("/api/login", json=login_data)
    token = login_response.json()["access_token"]
    
    # Test reel creation
    headers = {"Authorization": f"Bearer {token}"}
    reel_data = {
        "platform": "instagram",
        "reel_id": "test123",
        "url": "https://instagram.com/p/test123",
        "thumbnail_url": "https://example.com/thumb.jpg",
        "caption": "Test reel",
        "author": "@testuser",
        "tags": ["test", "demo"],
        "reel_metadata": {"likes": 100, "views": 1000}
    }
    response = client.post("/api/reels", json=reel_data, headers=headers)
    assert response.status_code == 200
    assert response.json()["reel_id"] == "test123"
    assert response.json()["platform"] == "instagram"

def test_get_reels():
    # First login to get token
    login_data = {
        "email": "test@example.com",
        "password": "TestPassword123"
    }
    login_response = client.post("/api/login", json=login_data)
    token = login_response.json()["access_token"]
    
    # Test getting reels
    headers = {"Authorization": f"Bearer {token}"}
    response = client.get("/api/reels", headers=headers)
    assert response.status_code == 200
    assert isinstance(response.json(), list)

def test_delete_reel():
    # First login to get token
    login_data = {
        "email": "test@example.com",
        "password": "TestPassword123"
    }
    login_response = client.post("/api/login", json=login_data)
    token = login_response.json()["access_token"]
    
    # First get reels to find one to delete
    headers = {"Authorization": f"Bearer {token}"}
    reels_response = client.get("/api/reels", headers=headers)
    if len(reels_response.json()) > 0:
        reel_id = reels_response.json()[0]["id"]
        response = client.delete(f"/api/reels/{reel_id}", headers=headers)
        assert response.status_code == 200
        assert response.json()["message"] == "Reel deleted successfully" 