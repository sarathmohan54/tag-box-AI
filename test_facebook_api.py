import requests
import json
import os
from datetime import datetime

# Facebook API credentials
FACEBOOK_APP_ID = "550689493956425"
FACEBOOK_APP_SECRET = "7e9bd9bd4fc685ff8bb587919690ed09"
# To generate Facebook access token:
# 1. Go to https://developers.facebook.com/tools/explorer/
# 2. Select the Facebook app (ID: 550689493956425)
# 3. Click "Add a permission" and select:
#    - pages_read_engagement
#    - pages_show_list
#    - pages_read_user_content
#    - threads_oembed_read
# 4. Click "Generate Access Token"
FACEBOOK_ACCESS_TOKEN = "EAAH02WOrN0kBO5Yx3x2fH0plZABbu2c4fPIW3jSE53bhhR0o4CpT0EXh0x0o1LGqrmLHIgKZB1RBcGK3tQyo55iM4azpeZCwuPfn5dJlZAxJqWSyE9GLRBOqoWoHgOUsgQUZAY4CMkSJAusp9nSWfjvH967tZAH374NzlPJEqB34tOrPJi9TRHcYCHdZB3keV1CKljiNDKKZACqBTnMUbdyX2lpGSmYZD"

# Threads API credentials
THREADS_APP_ID = "9093082040777888"
THREADS_APP_SECRET = "107e55bf6649fa3c1e2284592bcbdc17"
# To generate Threads access token:
# 1. Go to https://developers.facebook.com/tools/explorer/
# 2. Select the Threads app (ID: 9093082040777888)
# 3. Click "Add a permission" and select:
#    - threads_oembed_read
# 4. Click "Generate Access Token"
THREADS_ACCESS_TOKEN = "your_threads_access_token"  # Usually same as Facebook token

# Test URLs
TEST_URLS = [
    # Facebook URLs
    "https://www.facebook.com/reel/1278526879505760",  # Sample Facebook reel
    # Threads URLs
    # "https://www.threads.net/@user/post/your_post_id",  # Commented out until we have Threads token
]

def check_permissions(platform="facebook"):
    """Check what permissions are granted to the access token"""
    print(f"\n1. Checking {platform.title()} Token Permissions...")
    
    access_token = THREADS_ACCESS_TOKEN if platform == "threads" else FACEBOOK_ACCESS_TOKEN
    
    url = f"https://graph.facebook.com/v18.0/me/permissions"
    params = {
        "access_token": access_token
    }
    
    try:
        response = requests.get(url, params=params)
        data = response.json()
        
        print(f"Status Code: {response.status_code}")
        if response.status_code == 200:
            permissions = data.get('data', [])
            print("\nGranted Permissions:")
            for perm in permissions:
                status = "✅" if perm['status'] == 'granted' else "❌"
                print(f"{status} {perm['permission']}")
            
            # Check for specific required permissions
            required_permissions = {
                'threads_oembed_read',
                'pages_read_engagement',
                'pages_show_list',
                'pages_read_user_content'
            } if platform == "facebook" else {
                'threads_oembed_read'
            }
            
            granted_permissions = {
                perm['permission'] for perm in permissions 
                if perm['status'] == 'granted'
            }
            
            missing_permissions = required_permissions - granted_permissions
            if missing_permissions:
                print(f"\n⚠️ Missing required {platform.title()} permissions:")
                for perm in missing_permissions:
                    print(f"❌ {perm}")
                print("\nPlease add these permissions when generating your access token at:")
                print("https://developers.facebook.com/tools/explorer/")
        else:
            print("Response:", json.dumps(data, indent=2))
            
    except Exception as e:
        print(f"❌ Error checking permissions: {e}")

def test_access_token(platform="facebook"):
    """Test if the access token is valid"""
    print(f"\n2. Testing {platform.title()} Access Token...")
    
    app_id = THREADS_APP_ID if platform == "threads" else FACEBOOK_APP_ID
    app_secret = THREADS_APP_SECRET if platform == "threads" else FACEBOOK_APP_SECRET
    access_token = THREADS_ACCESS_TOKEN if platform == "threads" else FACEBOOK_ACCESS_TOKEN
    
    url = f"https://graph.facebook.com/v18.0/debug_token"
    params = {
        "input_token": access_token,
        "access_token": f"{app_id}|{app_secret}"
    }
    
    try:
        response = requests.get(url, params=params)
        data = response.json()
        
        print(f"Status Code: {response.status_code}")
        print("Response:", json.dumps(data, indent=2))
        
        if response.status_code == 200:
            token_data = data.get("data", {})
            if token_data.get("is_valid"):
                print("✅ Access token is valid!")
                print(f"Token expires: {datetime.fromtimestamp(token_data['expires_at'])}")
                print(f"App ID: {token_data.get('app_id')}")
                print(f"User ID: {token_data.get('user_id')}")
                scopes = token_data.get('scopes', [])
                if scopes:
                    print("\nToken Scopes:")
                    for scope in scopes:
                        print(f"- {scope}")
                return True
            else:
                error = token_data.get("error", {}).get("message")
                print(f"❌ Token is invalid: {error}")
        else:
            print("❌ Access token is invalid or expired")
            if 'error' in data:
                print(f"Error: {data['error'].get('message')}")
        return False
            
    except Exception as e:
        print(f"❌ Error testing access token: {e}")
        return False

def is_threads_url(url):
    """Check if the URL is a Threads URL"""
    return 'threads.net' in url

def test_video_metadata(url):
    """Test fetching video metadata"""
    platform = "threads" if is_threads_url(url) else "facebook"
    print(f"\n3. Testing {platform.title()} metadata fetch for: {url}")
    
    access_token = THREADS_ACCESS_TOKEN if platform == "threads" else FACEBOOK_ACCESS_TOKEN
    
    if platform == "threads":
        # Handle Threads URL
        print("\nTrying Threads oembed endpoint...")
        oembed_url = f"https://graph.facebook.com/v18.0/oembed_video"
        oembed_params = {
            "access_token": access_token,
            "url": url
        }
        
        try:
            response = requests.get(oembed_url, params=oembed_params)
            data = response.json()
            print(f"Oembed Status Code: {response.status_code}")
            print("Oembed Response:", json.dumps(data, indent=2))
            return response.status_code == 200
        except Exception as e:
            print(f"❌ Error fetching Threads metadata: {e}")
            return False
    
    else:
        # Handle Facebook URL
        # Try to extract video ID from URL
        import re
        patterns = [
            r'facebook\.com/.*?/videos/(\d+)',
            r'facebook\.com/watch/\?v=(\d+)',
            r'fb\.watch/(\w+)',
            r'/share/r/(\w+)',
            r'/share/v/(\w+)',
            r'/reel/(\d+)',
        ]
        
        video_id = None
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                video_id = match.group(1)
                break
        
        if not video_id:
            print("❌ Could not extract video ID from URL")
            return False
        
        print(f"Found video ID: {video_id}")
        
        # First try with oembed endpoint
        print("\nTrying Facebook oembed endpoint...")
        oembed_url = f"https://graph.facebook.com/v18.0/oembed_video"
        oembed_params = {
            "access_token": access_token,
            "url": url
        }
        
        try:
            response = requests.get(oembed_url, params=oembed_params)
            data = response.json()
            print(f"Oembed Status Code: {response.status_code}")
            print("Oembed Response:", json.dumps(data, indent=2))
        except Exception as e:
            print(f"⚠️ Oembed request failed: {e}")
        
        # Try to fetch video metadata
        print("\nTrying video metadata endpoint...")
        url = f"https://graph.facebook.com/v18.0/{video_id}"
        params = {
            "access_token": access_token,
            "fields": "description,title,thumbnail_url,permalink_url,from,source,format"
        }
        
        try:
            response = requests.get(url, params=params)
            data = response.json()
            
            print(f"Status Code: {response.status_code}")
            print("Response:", json.dumps(data, indent=2))
            
            if response.status_code == 200:
                print("✅ Successfully fetched video metadata!")
                return True
            else:
                print("❌ Failed to fetch video metadata")
                if 'error' in data:
                    print(f"Error: {data['error'].get('message')}")
                return False
                
        except Exception as e:
            print(f"❌ Error fetching video metadata: {e}")
            return False

def main():
    print("Meta API Test Script")
    print("=" * 50)
    
    # Test Facebook integration
    print("\nTesting Facebook Integration:")
    print("=" * 30)
    check_permissions("facebook")
    facebook_token_valid = test_access_token("facebook")
    
    # Test Threads integration
    print("\nTesting Threads Integration:")
    print("=" * 30)
    check_permissions("threads")
    threads_token_valid = test_access_token("threads")
    
    if not (facebook_token_valid or threads_token_valid):
        print("\n❌ All token tests failed. Please check your credentials.")
        return
    
    # Test URL metadata fetching
    success = 0
    total = len(TEST_URLS)
    
    for url in TEST_URLS:
        if test_video_metadata(url):
            success += 1
    
    print("\nTest Summary")
    print("=" * 50)
    print(f"Facebook Token: {'✅ Valid' if facebook_token_valid else '❌ Invalid'}")
    print(f"Threads Token: {'✅ Valid' if threads_token_valid else '❌ Invalid'}")
    print(f"URL Tests: {success}/{total} successful")

if __name__ == "__main__":
    main() 