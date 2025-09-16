#!/bin/bash

echo "=== Fixing Revolt Bot Permissions ==="
echo "This script will fix permission issues that may prevent the bot from running properly."

# Find all server directories and fix their permissions
echo "Looking for server directories..."
for dir in server-*; do
    if [ -d "$dir" ]; then
        echo "Fixing permissions for: $dir"
        chmod -R 755 "$dir"
        chown -R $(whoami):$(whoami) "$dir"
    fi
done

# Clean up any temporary browser data directories
echo "Cleaning up temporary browser data directories..."
rm -rf /tmp/revolt-bot-*

echo "✅ Permission fix completed!"
echo "You can now run the bot with: ./start.sh --user your_username"
