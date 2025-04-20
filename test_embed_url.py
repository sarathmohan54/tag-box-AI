import requests
from urllib.parse import quote_plus, urlparse
import sys

def get_final_url(url):
    try:
        # Follow redirects to get the final URL
        response = requests.get(url, allow_redirects=True)
        final_url = response.url
        print(f"\nRedirect chain:")
        print("-" * 50)
        print(f"Initial URL: {url}")
        print(f"Final URL: {final_url}")
        return final_url
    except Exception as e:
        print(f"Error following redirects: {e}")
        return url

def get_embed_url(url):
    # First get the final URL after any redirects
    final_url = get_final_url(url)
    
    # Encode the final URL
    encoded_url = quote_plus(final_url)
    
    # Generate embed URL
    embed_url = f"https://www.facebook.com/plugins/video.php?href={encoded_url}&show_text=false"
    
    # Generate thumbnail URL
    thumbnail_url = f"{embed_url}&t=0"
    
    print("\nFacebook URL Analysis:")
    print("=" * 50)
    print(f"Original URL: {url}")
    print(f"Final URL after redirects: {final_url}")
    print("\nEmbed URLs:")
    print("-" * 50)
    print(f"Video Embed URL:\n{embed_url}")
    print(f"\nThumbnail URL:\n{thumbnail_url}")
    print("\nHTML Embed Code:")
    print("-" * 50)
    print(f'<iframe src="{embed_url}" width="560" height="315" style="border:none;overflow:hidden" scrolling="no" frameborder="0" allowfullscreen="true" allow="autoplay; clipboard-write; encrypted-media; picture-in-picture; web-share"></iframe>')

    # Also try direct video URL format
    parsed = urlparse(final_url)
    path_parts = parsed.path.strip('/').split('/')
    if len(path_parts) > 1 and path_parts[-2] in ['videos', 'watch', 'reel']:
        video_id = path_parts[-1].split('?')[0]
        print(f"\nDirect Video URL (alternative):")
        print("-" * 50)
        direct_url = f"https://www.facebook.com/watch?v={video_id}"
        encoded_direct = quote_plus(direct_url)
        direct_embed = f"https://www.facebook.com/plugins/video.php?href={encoded_direct}&show_text=false"
        print(f"Video ID: {video_id}")
        print(f"Direct embed URL:\n{direct_embed}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        url = sys.argv[1]
    else:
        url = input("Enter Facebook video URL: ")
    
    get_embed_url(url) 