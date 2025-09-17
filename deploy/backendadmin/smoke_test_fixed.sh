#!/bin/bash

BASE_URL="https://admin.livekit.lovedrop.live"
FAILED=0

echo "=== Starting Smoke Test ==="
echo

# Test health check
echo -n "Testing /up (health check)... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/up")
if [ "$STATUS" = "200" ]; then
    echo "✅ PASS (HTTP $STATUS)"
else
    echo "❌ FAIL (HTTP $STATUS)"
    FAILED=$((FAILED + 1))
fi

# Test videos endpoint (previously failing)
echo -n "Testing /videos endpoint... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/videos")
if [ "$STATUS" = "200" ]; then
    echo "✅ PASS (HTTP $STATUS)"
else
    echo "❌ FAIL (HTTP $STATUS)"
    FAILED=$((FAILED + 1))
fi

# Test root endpoint
echo -n "Testing / (root)... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/")
if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
    echo "✅ PASS (HTTP $STATUS)"
else
    echo "❌ FAIL (HTTP $STATUS)"
    FAILED=$((FAILED + 1))
fi

# Test assets are being served (check for fingerprinted assets)
echo -n "Testing asset pipeline... "
RESPONSE=$(curl -s "$BASE_URL/videos" | grep -o 'application-[a-f0-9]*\.css')
if [ ! -z "$RESPONSE" ]; then
    echo "✅ PASS (found fingerprinted asset: $RESPONSE)"
else
    echo "❌ FAIL (no fingerprinted assets found)"
    FAILED=$((FAILED + 1))
fi

# Test database connectivity via videos endpoint content
echo -n "Testing database connectivity... "
RESPONSE=$(curl -s "$BASE_URL/videos")
# Check for actual Rails error pages, not just the word "error" in HTML
if echo "$RESPONSE" | grep -q "ActionController::RoutingError\|ActiveRecord::\|NoMethodError\|SyntaxError\|LoadError"; then
    echo "❌ FAIL (Rails errors in response)"
    FAILED=$((FAILED + 1))
elif echo "$RESPONSE" | grep -q "<title>.*Error.*</title>"; then
    echo "❌ FAIL (Error page detected)"
    FAILED=$((FAILED + 1))
else
    echo "✅ PASS (no Rails errors detected)"
fi

# Test that videos page loads without schema caching errors
echo -n "Testing schema caching fix... "
RESPONSE=$(curl -s "$BASE_URL/videos")
if echo "$RESPONSE" | grep -q "Could not find table"; then
    echo "❌ FAIL (schema caching error still present)"
    FAILED=$((FAILED + 1))
else
    echo "✅ PASS (no schema caching errors)"
fi

echo
echo "=== Smoke Test Results ==="
if [ $FAILED -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ $FAILED test(s) failed"
    exit 1
fi
