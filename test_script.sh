#!/bin/bash

# Test the registration API endpoint
REGISTER_URL="http://localhost:8000/api/register"
REGISTER_DATA='{
    "email": "test@example.com",
    "password": "password123"
}'

echo "Testing registration endpoint..."
echo "Request data: $REGISTER_DATA"
register_response=$(curl -v -s -w "\nHTTP_CODE:%{http_code}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "$REGISTER_DATA" \
  -X POST "$REGISTER_URL" 2>&1)

register_http_code=$(echo "$register_response" | grep HTTP_CODE | awk -F: '{print $2}')

echo "Registration Response: $register_response"
echo "Registration HTTP Status Code: $register_http_code"

if [ "$register_http_code" -eq 200 ]; then
  echo "Registration test passed."
else
  echo "Registration test failed."
fi

# Test the login API endpoint
LOGIN_URL="http://localhost:8000/api/login"
LOGIN_DATA='{
    "email": "test@example.com",
    "password": "password123"
}'

echo -e "\nTesting login endpoint..."
echo "Request data: $LOGIN_DATA"
login_response=$(curl -v -s -w "\nHTTP_CODE:%{http_code}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "$LOGIN_DATA" \
  -X POST "$LOGIN_URL" 2>&1)

login_http_code=$(echo "$login_response" | grep HTTP_CODE | awk -F: '{print $2}')

echo "Login Response: $login_response"
echo "Login HTTP Status Code: $login_http_code"

if [ "$login_http_code" -eq 200 ]; then
  echo "Login test passed."
else
  echo "Login test failed."
fi 