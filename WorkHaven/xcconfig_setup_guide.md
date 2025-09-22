# xcconfig Setup Guide - Alternative Methods

## Method 1: Search for "xcconfig" in Build Settings

1. **In Build Settings tab, click the search box**
2. **Type "xcconfig"** (not "Config File")
3. **Look for "Configuration Settings File"** in the results
4. **Set it to `secrets.xcconfig`** for both Debug and Release

## Method 2: Use "All" View Instead of "Basic"

1. **In Build Settings tab, look for a toggle at the top**
2. **Switch from "Basic" to "All"** (or "Customized")
3. **Search for "Configuration Settings File"**
4. **Set it to `secrets.xcconfig`**

## Method 3: Manual Project File Editing (Advanced)

If the GUI doesn't work, you can edit the project file directly:

1. **Close Xcode**
2. **Open `WorkHaven.xcodeproj/project.pbxproj` in a text editor**
3. **Find the section with your target configuration**
4. **Add these lines:**
```
buildSettings = {
    // ... existing settings ...
    INFOPLIST_FILE = "WorkHaven/Info.plist";
    CONFIGURATION_SETTINGS_FILE = "secrets.xcconfig";
};
```

## Method 4: Alternative - Use Build Phases

1. **Select your target**
2. **Go to "Build Phases" tab**
3. **Add a "Run Script Phase"**
4. **Add this script:**
```bash
# Load xcconfig file
source secrets.xcconfig
export GROK_API_KEY
```

## Method 5: Direct Info.plist Approach (Simplest)

Since the xcconfig is being difficult, just add the API key directly to Info.plist:

1. **Open `WorkHaven/Info.plist`**
2. **Add this before `</dict>`:**
```xml
<key>GROK_API_KEY</key>
<string>YOUR_GROK_API_KEY_HERE</string>
```

## Verification

After any method, build the project and check console for:
- `✅ Found Grok API key in xcconfig: xai-nBTAGe...` (if xcconfig works)
- `✅ Found Grok API key in Info.plist: xai-nBTAGe...` (if Info.plist method)

## Troubleshooting

- **If nothing shows up**: Try Method 5 (Info.plist) - it's the most reliable
- **If xcconfig still doesn't work**: The Info.plist method will work immediately
- **Check file path**: Make sure `secrets.xcconfig` is in the `WorkHaven/` folder
