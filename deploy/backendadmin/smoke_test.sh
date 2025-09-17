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

# Test assets are being served
echo -n "Testing asset pipeline... "
RESPONSE=$(curl -s -I "$BASE_URL/assets/application.css" | head -n 1)
if echo "$RESPONSE" | grep -q "200\|304"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    FAILED=$((FAILED + 1))
fi

# Test database connectivity via videos endpoint content
echo -n "Testing database connectivity... "
RESPONSE=$(curl -s "$BASE_URL/videos")
if echo "$RESPONSE" | grep -q "error\|Error\|exception"; then
    echo "❌ FAIL (errors in response)"
    FAILED=$((FAILED + 1))
else
    echo "✅ PASS (no errors detected)"
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
