#!/bin/bash

# =============================================================================
# Revolt Bot - Performance Test Script
# =============================================================================
# This script tests the performance of the optimized bot
# =============================================================================

echo "🚀 Revolt Bot Performance Test"
echo "=============================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Test 1: Startup Time
echo "Test 1: Bot Startup Time"
echo "-----------------------"
start_time=$(date +%s%3N)

# Start bot in background
node puppeteer_revolt.js --user performance-test &
BOT_PID=$!

# Wait for bot to start
sleep 5

end_time=$(date +%s%3N)
startup_time=$((end_time - start_time))

print_status "Bot started in ${startup_time}ms"

# Test 2: Memory Usage
echo ""
echo "Test 2: Memory Usage"
echo "-------------------"
memory_usage=$(ps -o rss= -p $BOT_PID 2>/dev/null | awk '{print $1/1024 " MB"}')
print_status "Memory usage: $memory_usage"

# Test 3: Web Dashboard Response Time
echo ""
echo "Test 3: Web Dashboard Response Time"
echo "----------------------------------"
dashboard_start=$(date +%s%3N)
curl -s http://localhost:1024 > /dev/null
dashboard_end=$(date +%s%3N)
dashboard_time=$((dashboard_end - dashboard_start))

print_status "Dashboard response time: ${dashboard_time}ms"

# Test 4: API Response Time
echo ""
echo "Test 4: API Response Time"
echo "------------------------"
api_start=$(date +%s%3N)
curl -s http://localhost:1024/api/servers > /dev/null
api_end=$(date +%s%3N)
api_time=$((api_end - api_start))

print_status "API response time: ${api_time}ms"

# Test 5: Browser Launch Time
echo ""
echo "Test 5: Browser Launch Test"
echo "---------------------------"
browser_start=$(date +%s%3N)

# Check if Chromium processes are running
sleep 2
chromium_count=$(ps aux | grep chromium | grep -v grep | wc -l)
browser_end=$(date +%s%3N)
browser_time=$((browser_end - browser_start))

print_status "Browser processes detected: $chromium_count"
print_status "Browser detection time: ${browser_time}ms"

# Performance Summary
echo ""
echo "Performance Summary"
echo "=================="
echo "Startup Time: ${startup_time}ms"
echo "Memory Usage: $memory_usage"
echo "Dashboard Response: ${dashboard_time}ms"
echo "API Response: ${api_time}ms"
echo "Browser Detection: ${browser_time}ms"

# Performance Rating
echo ""
echo "Performance Rating"
echo "=================="

if [ $startup_time -lt 5000 ]; then
    print_status "Startup: EXCELLENT (< 5s)"
elif [ $startup_time -lt 10000 ]; then
    print_status "Startup: GOOD (< 10s)"
else
    print_warning "Startup: NEEDS IMPROVEMENT (> 10s)"
fi

if [ $dashboard_time -lt 100 ]; then
    print_status "Dashboard: EXCELLENT (< 100ms)"
elif [ $dashboard_time -lt 500 ]; then
    print_status "Dashboard: GOOD (< 500ms)"
else
    print_warning "Dashboard: NEEDS IMPROVEMENT (> 500ms)"
fi

if [ $api_time -lt 50 ]; then
    print_status "API: EXCELLENT (< 50ms)"
elif [ $api_time -lt 200 ]; then
    print_status "API: GOOD (< 200ms)"
else
    print_warning "API: NEEDS IMPROVEMENT (> 200ms)"
fi

# Cleanup
echo ""
echo "Cleaning up..."
kill $BOT_PID 2>/dev/null
sleep 2
rm -rf server-performance-test

print_status "Performance test completed!"
echo ""
echo "💡 Tips for better performance:"
echo "   - Use --headless=true for production"
echo "   - Increase memory with: export NODE_OPTIONS='--max-old-space-size=4096'"
echo "   - Use SSD storage for faster file operations"
echo "   - Close unnecessary applications to free up resources"
