#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# API Base URL
API_URL="http://localhost:8000"

# Test credentials
TEST_EMAIL="test_$(date +%s)@example.com"
TEST_PASSWORD="TestPassword123"

# Facebook test URLs - multiple formats for testing
FB_URLS=(
    "https://www.facebook.com/watch?v=1234567890123456"  # Public Facebook video
    "https://www.facebook.com/reel/1234567890123456"    # Public Facebook reel
    "https://www.facebook.com/share/v/abcdefghijk/"     # Public Facebook share
)

echo -e "${YELLOW}Starting test sequence...${NC}"
echo "----------------------------------------"

# Function to register user
register_user() {
    echo -e "${YELLOW}Registering test user...${NC}"
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"email\": \"$TEST_EMAIL\", \"password\": \"$TEST_PASSWORD\"}" \
        "$API_URL/api/register")
    
    if echo "$response" | jq -e '.access_token' > /dev/null; then
        echo -e "${GREEN}✓ User registered successfully${NC}"
        echo "$response" | jq .
        return 0
    else
        echo -e "${RED}✗ Registration failed or user exists${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# Function to login user
login_user() {
    echo -e "\n${YELLOW}Logging in test user...${NC}"
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"email\": \"$TEST_EMAIL\", \"password\": \"$TEST_PASSWORD\"}" \
        "$API_URL/api/login")
    
    if echo "$response" | jq -e '.access_token' > /dev/null; then
        echo -e "${GREEN}✓ Login successful${NC}"
        TOKEN=$(echo "$response" | jq -r '.access_token')
        echo "Token obtained successfully"
        return 0
    else
        echo -e "${RED}✗ Login failed${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# Function to check if URL is accessible
check_url() {
    local url=$1
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ URL is accessible (HTTP 200)${NC}"
        return 0
    else
        echo -e "${RED}✗ URL is not accessible (HTTP $http_code)${NC}"
        return 1
    fi
}

# Function to test URL extraction
test_url() {
    local url=$1
    local token=$2
    echo -e "\n${YELLOW}Testing URL: $url${NC}"
    
    # Make API call to extract info
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d "{\"url\": \"$url\"}" \
        "$API_URL/api/extract-reel-info")
    
    # Check if response is valid JSON
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        echo -e "${RED}Error: Invalid JSON response${NC}"
        echo "Raw response: $response"
        echo "----------------------------------------"
        return 1
    fi
    
    echo "Response:"
    echo "$response" | jq .
    
    # Extract and test primary thumbnail URL
    thumbnail_url=$(echo "$response" | jq -r '.thumbnail_url // empty')
    
    if [ ! -z "$thumbnail_url" ]; then
        echo -e "\nTesting primary thumbnail URL: $thumbnail_url"
        check_url "$thumbnail_url"
        
        # Try to download thumbnail
        echo -e "\nAttempting to download primary thumbnail..."
        if curl -s "$thumbnail_url" -o "thumbnail_primary_$(date +%s).jpg"; then
            echo -e "${GREEN}✓ Primary thumbnail downloaded successfully${NC}"
        else
            echo -e "${RED}✗ Failed to download primary thumbnail${NC}"
        fi
    else
        echo -e "${RED}No primary thumbnail URL found in response${NC}"
    fi
    
    # Test all alternative thumbnail URLs
    echo -e "\nTesting alternative thumbnail URLs..."
    thumbnail_urls=$(echo "$response" | jq -r '.metadata.thumbnail_urls[]? // empty')
    
    if [ ! -z "$thumbnail_urls" ]; then
        while IFS= read -r alt_url; do
            echo -e "\nTesting alternative URL: $alt_url"
            check_url "$alt_url"
            
            echo "Attempting to download alternative thumbnail..."
            if curl -s "$alt_url" -o "thumbnail_alt_$(date +%s).jpg"; then
                echo -e "${GREEN}✓ Alternative thumbnail downloaded successfully${NC}"
            else
                echo -e "${RED}✗ Failed to download alternative thumbnail${NC}"
            fi
        done <<< "$thumbnail_urls"
    fi
    
    # Extract and display other important fields
    platform=$(echo "$response" | jq -r '.platform // "N/A"')
    reel_id=$(echo "$response" | jq -r '.reel_id // "N/A"')
    caption=$(echo "$response" | jq -r '.caption // "N/A"')
    author=$(echo "$response" | jq -r '.author // "N/A"')
    
    echo -e "\nExtracted Information:"
    echo -e "Platform: ${GREEN}$platform${NC}"
    echo -e "Reel ID: ${GREEN}$reel_id${NC}"
    echo -e "Caption: ${GREEN}$caption${NC}"
    echo -e "Author: ${GREEN}$author${NC}"
    
    echo "----------------------------------------"
}

# Main test sequence
echo "1. Attempting to register user..."
register_user

echo "2. Attempting to login..."
if login_user; then
    echo "3. Testing Facebook URL extraction..."
    for url in "${FB_URLS[@]}"; do
        test_url "$url" "$TOKEN"
        echo "----------------------------------------"
        sleep 2  # Add delay between tests
    done
else
    echo -e "${RED}Failed to obtain token. Cannot proceed with URL testing.${NC}"
    exit 1
fi

echo -e "${YELLOW}Tests completed${NC}" 