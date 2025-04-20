import requests
import json

BASE_URL = "http://192.168.1.6:8000"

def test_login():
    url = f"{BASE_URL}/api/login"
    
    # Your test account credentials
    data = {
        "email": "sarathmohanm@gmail.com",
        "password": "Test@123"  # Replace with your actual test password
    }
    
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    print(f"\nTesting login endpoint: {url}")
    print(f"Request data: {json.dumps(data, indent=2)}")
    print(f"Request headers: {json.dumps(headers, indent=2)}")
    
    try:
        # Make request with increased timeout and headers
        response = requests.post(url, json=data, headers=headers, timeout=10)
        
        print(f"\nStatus Code: {response.status_code}")
        print(f"Response Headers: {json.dumps(dict(response.headers), indent=2)}")
        print(f"Response Body: {json.dumps(response.json(), indent=2)}")
        
        return response.status_code == 200
        
    except requests.exceptions.ConnectionError as e:
        print(f"\nConnection Error: {e}")
        print("This might indicate:")
        print("1. The server is not running")
        print("2. The IP address is not reachable")
        print("3. The port is blocked")
        print("\nTrying to ping the server...")
        import os
        os.system(f"ping -c 4 192.168.1.6")
        return False
        
    except requests.exceptions.Timeout as e:
        print(f"\nTimeout Error: {e}")
        print("The server took too long to respond")
        return False
        
    except Exception as e:
        print(f"\nUnexpected Error: {type(e).__name__}")
        print(f"Error Details: {e}")
        return False

def test_server_connection():
    url = BASE_URL
    print(f"\nTesting base server connection: {url}")
    
    try:
        response = requests.get(url, timeout=5)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        return True
    except Exception as e:
        print(f"Error connecting to server: {e}")
        return False

if __name__ == "__main__":
    print("Starting API Tests...")
    
    # First test basic server connection
    if test_server_connection():
        print("\n✅ Server is reachable")
        
        # Then test login
        if test_login():
            print("\n✅ Login test successful")
        else:
            print("\n❌ Login test failed")
    else:
        print("\n❌ Server is not reachable") 