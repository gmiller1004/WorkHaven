#!/bin/bash

# Script to automatically configure xcconfig file in Xcode project
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

# Check if the file is already in the Xcode project
if grep -q "secrets.xcconfig" "WorkHaven.xcodeproj/project.pbxproj"; then
    echo "✅ secrets.xcconfig is already added to the Xcode project"
else
    echo "⚠️  secrets.xcconfig is not in the Xcode project yet"
    echo "📋 Please add it manually:"
    echo "   1. Open WorkHaven.xcodeproj in Xcode"
    echo "   2. Right-click on WorkHaven project → Add Files to WorkHaven"
    echo "   3. Select WorkHaven/secrets.xcconfig"
    echo "   4. Make sure 'Add to target' is checked"
    echo "   5. Click 'Add'"
fi

# Check if build settings are configured
echo ""
echo "🔍 Checking build settings configuration..."

# This is a simplified check - in reality, you'd need to parse the project.pbxproj file
if grep -q "secrets.xcconfig" "WorkHaven.xcodeproj/project.pbxproj"; then
    echo "✅ xcconfig file is referenced in project"
else
    echo "❌ xcconfig file is not properly configured"
fi

echo ""
echo "📋 Manual Configuration Steps:"
echo ""
echo "1. Add xcconfig to Xcode project:"
echo "   - Right-click on WorkHaven project in navigator"
echo "   - Select 'Add Files to WorkHaven'"
echo "   - Navigate to and select 'WorkHaven/secrets.xcconfig'"
echo "   - Make sure 'Add to target' is checked for WorkHaven"
echo "   - Click 'Add'"
echo ""
echo "2. Configure Build Settings:"
echo "   - Select the WorkHaven project in the navigator"
echo "   - Select the WorkHaven target"
echo "   - Go to 'Build Settings' tab"
echo "   - Search for 'Config File' or 'Configuration Settings File'"
echo "   - Set 'Configuration Settings File' to 'secrets.xcconfig' for both Debug and Release"
echo ""
echo "3. Verify the configuration:"
echo "   - Build the project (Cmd+B)"
echo "   - Check console for: '✅ Found Grok API key in xcconfig: xai-nBTAGe...'"
echo ""

# Test if the API key is accessible
echo "🧪 Testing API key access..."
if [ -f "WorkHaven/Info.plist" ] && grep -q "GROK_API_KEY" "WorkHaven/Info.plist"; then
    echo "✅ API key found in Info.plist (fallback method)"
    echo "   This should work immediately for testing"
else
    echo "❌ API key not found in Info.plist"
    echo "   Please add it manually or configure xcconfig"
fi

echo ""
echo "✅ Configuration script completed!"
echo ""
echo "🚀 After completing the manual steps, rebuild the project and test the auto-discovery feature."
echo "   The app should now find the Grok API key and enable spot discovery."
