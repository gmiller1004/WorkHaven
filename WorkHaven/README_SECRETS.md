# Secrets Configuration

## Setting up API Keys

### 1. Configure Grok API Key

1. Open `secrets.xcconfig` in Xcode
2. Replace `YOUR_GROK_API_KEY_HERE` with your actual Grok API key
3. Save the file

### 2. Add xcconfig to Xcode Project

1. In Xcode, right-click on the WorkHaven project
2. Select "Add Files to WorkHaven"
3. Navigate to and select `secrets.xcconfig`
4. Make sure "Add to target" is checked for WorkHaven
5. Click "Add"

### 3. Configure Build Settings

1. Select the WorkHaven project in the navigator
2. Select the WorkHaven target
3. Go to "Build Settings" tab
4. Search for "Config File"
5. Set "Configuration Settings File" to `secrets.xcconfig` for both Debug and Release

### 4. Verify Configuration

The SpotDiscoveryService will automatically read the API key from the xcconfig file. You can verify it's working by checking the service's `hasGrokAPIKey()` method.

## Security Notes

- The `secrets.xcconfig` file is already added to `.gitignore`
- Never commit API keys to version control
- Keep your API keys secure and rotate them regularly
- The xcconfig file should only contain non-sensitive configuration values

## File Structure

```
WorkHaven/
├── secrets.xcconfig          # API keys and secrets (not committed)
├── .gitignore               # Includes secrets.xcconfig
└── Services/
    └── SpotDiscoveryService.swift  # Reads from xcconfig
```
