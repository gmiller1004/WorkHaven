#!/bin/bash

# Script to configure xcconfig file in Xcode project
# This script helps integrate the secrets.xcconfig file with the Xcode project

echo "🔧 Configuring xcconfig file for WorkHaven..."

# Check if we're in the right directory
if [ ! -f "WorkHaven.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the WorkHaven project root directory"
    exit 1
fi

# Check if secrets.xcconfig exists
if [ ! -f "WorkHaven/secrets.xcconfig" ]; then
    echo "❌ Error: secrets.xcconfig file not found in WorkHaven/ directory"
    exit 1
fi

echo "✅ Found secrets.xcconfig file"

# Instructions for manual configuration
echo ""
echo "📋 Manual Configuration Steps:"
echo ""
echo "1. Open WorkHaven.xcodeproj in Xcode"
echo ""
echo "2. Add the xcconfig file to the project:"
echo "   - Right-click on the WorkHaven project in the navigator"
echo "   - Select 'Add Files to WorkHaven'"
echo "   - Navigate to and select 'WorkHaven/secrets.xcconfig'"
echo "   - Make sure 'Add to target' is checked for WorkHaven"
echo "   - Click 'Add'"
echo ""
echo "3. Configure Build Settings:"
echo "   - Select the WorkHaven project in the navigator"
echo "   - Select the WorkHaven target"
echo "   - Go to 'Build Settings' tab"
echo "   - Search for 'Config File' or 'Configuration Settings File'"
echo "   - Set 'Configuration Settings File' to 'secrets.xcconfig' for both Debug and Release"
echo ""
echo "4. Alternative: Add to Info.plist:"
echo "   - Open WorkHaven/Info.plist"
echo "   - Add a new key 'GROK_API_KEY' with your API key as the value"
echo ""

# Check if we can add it to Info.plist as a fallback
if [ -f "WorkHaven/Info.plist" ]; then
    echo "🔧 Adding API key to Info.plist as fallback..."
    
    # Read the current Info.plist
    plist_file="WorkHaven/Info.plist"
    
    # Check if GROK_API_KEY already exists
    if grep -q "GROK_API_KEY" "$plist_file"; then
        echo "⚠️  GROK_API_KEY already exists in Info.plist"
    else
        # Add the API key to Info.plist
        # This is a simple approach - in a real scenario, you'd use plutil or a proper plist editor
        echo "📝 Note: You may need to manually add the API key to Info.plist"
        echo "   Add this key-value pair to Info.plist:"
        echo "   <key>GROK_API_KEY</key>"
        echo "   <string>YOUR_GROK_API_KEY_HERE</string>"
    fi
fi

echo ""
echo "✅ Configuration script completed!"
echo ""
echo "🚀 After completing the manual steps, rebuild the project and test the auto-discovery feature."
