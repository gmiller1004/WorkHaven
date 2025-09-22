#!/bin/bash

# Script to add Grok API key to Info.plist
# This is the simplest and most reliable method

echo "🔧 Adding Grok API key to Info.plist..."

# Check if we're in the right directory
if [ ! -f "WorkHaven/Info.plist" ]; then
    echo "❌ Error: WorkHaven/Info.plist not found. Please run from project root."
    exit 1
fi

# Check if API key is already there
if grep -q "GROK_API_KEY" "WorkHaven/Info.plist"; then
    echo "✅ GROK_API_KEY already exists in Info.plist"
    echo "📋 Current value:"
    grep -A 1 "GROK_API_KEY" "WorkHaven/Info.plist"
    exit 0
fi

# Create backup
cp "WorkHaven/Info.plist" "WorkHaven/Info.plist.backup"
echo "📋 Created backup: WorkHaven/Info.plist.backup"

# Add API key to Info.plist
echo "🔑 Adding API key to Info.plist..."

# Use sed to add the API key before the closing </dict> tag
sed -i '' '/^<\/dict>$/i\
	<key>GROK_API_KEY</key>\
	<string>YOUR_GROK_API_KEY_HERE</string>
' "WorkHaven/Info.plist"

if [ $? -eq 0 ]; then
    echo "✅ Successfully added GROK_API_KEY to Info.plist"
    echo "📋 Verification:"
    grep -A 1 "GROK_API_KEY" "WorkHaven/Info.plist"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Build the project (Cmd+B)"
    echo "   2. Check console for: '✅ Found Grok API key in Info.plist: xai-nBTAGe...'"
    echo "   3. Test auto-discovery in Settings"
else
    echo "❌ Failed to add API key to Info.plist"
    echo "📋 Please add manually:"
    echo "   <key>GROK_API_KEY</key>"
    echo "   <string>YOUR_GROK_API_KEY_HERE</string>"
fi
