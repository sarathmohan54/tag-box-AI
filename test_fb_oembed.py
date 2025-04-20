import requests
from urllib.parse import quote_plus
import json

def test_oembed(url):
    print(f"\nTesting URL: {url}")
    print("=" * 50)
    
    # 1. Try oEmbed endpoint
    encoded_url = quote_plus(url)
    oembed_url = f"https://www.facebook.com/plugins/post/oembed.json/?url={encoded_url}"
    
    print("\n1. Testing oEmbed endpoint:")
    print(f"URL: {oembed_url}")
    try:
        response = requests.get(oembed_url)
        print(f"Status: {response.status_code}")
        print("Response:", json.dumps(response.json(), indent=2) if response.status_code == 200 else response.text)
    except Exception as e:
        print(f"Error: {e}")

    # 2. Try video plugins endpoint
    plugins_url = f"https://www.facebook.com/plugins/video.php?href={encoded_url}&show_text=false"
    
    print("\n2. Testing video plugins endpoint:")
    print(f"URL: {plugins_url}")
    try:
        response = requests.get(plugins_url)
        print(f"Status: {response.status_code}")
        print(f"Content-Type: {response.headers.get('content-type', 'unknown')}")
        if response.status_code == 200:
            print("Success - This URL can be used in an iframe")
    except Exception as e:
        print(f"Error: {e}")

    # 3. Try following redirects for share URLs
    if '/share/' in url:
        print("\n3. Following share URL redirects:")
        try:
            response = requests.get(url, allow_redirects=True)
            print(f"Final URL: {response.url}")
            print(f"Status: {response.status_code}")
            if response.status_code == 200:
                print("Success - Got final video URL")
                # Test the final URL
                test_oembed(response.url)
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    # Test URLs from logs
    urls = [
        "https://www.facebook.com/share/r/12EAQDj6iye/",
        "https://www.facebook.com/share/v/1BsTqptbLh/",
        "https://www.facebook.com/share/r/1AF4swPv6U/",
        "https://www.facebook.com/share/r/19pfuoPpCr/"
    ]
    
    for url in urls:
        test_oembed(url) 