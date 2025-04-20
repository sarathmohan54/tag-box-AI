import requests
import json
from urllib.parse import quote_plus

def get_facebook_preview(url):
    try:
        # Get the embed version of the URL
        encoded_url = quote_plus(url)
        embed_url = f"https://www.facebook.com/plugins/video.php?href={encoded_url}"
        
        # Create preview data
        preview_data = {
            'embed_url': embed_url,
            'thumbnail_url': f"https://www.facebook.com/plugins/video.php?href={encoded_url}&show_text=false&t=0",
            'embed_html': f'<iframe src="{embed_url}" width="100%" height="100%" style="border:none;overflow:hidden" scrolling="no" frameborder="0" allowfullscreen="true" allow="autoplay; clipboard-write; encrypted-media; picture-in-picture; web-share"></iframe>'
        }
        
        return preview_data

    except Exception as e:
        print(f"Error generating preview: {e}")
        return None

# Test the function
if __name__ == "__main__":
    test_urls = [
        "https://www.facebook.com/reel/1278856269453499",
        "https://www.facebook.com/watch?v=1278856269453499",
        "https://fb.watch/1278856269453499/"
    ]
    
    for url in test_urls:
        print(f"\nTesting URL: {url}")
        preview = get_facebook_preview(url)
        print(json.dumps(preview, indent=2) if preview else "Failed to get preview") 