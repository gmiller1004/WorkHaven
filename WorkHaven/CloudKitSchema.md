# CloudKit Schema for WorkHaven

## Record Type: Spot

### Fields:
- `name` (String) - Spot name
- `address` (String) - Spot address
- `latitude` (Double) - Latitude coordinate
- `longitude` (Double) - Longitude coordinate
- `wifiRating` (Int64) - WiFi rating (1-5)
- `noiseRating` (String) - Noise level (Low/Medium/High)
- `outlets` (Int64) - Outlet availability (0/1)
- `tips` (String) - Optional tips
- `photoURL` (String) - Optional photo URL
- `lastModified` (Date/Time) - Last modification timestamp
- `localID` (String) - Local Core Data object ID

### Indexes:
- `name` (Queryable)
- `latitude` (Queryable)
- `longitude` (Queryable)
- `wifiRating` (Queryable)
- `noiseRating` (Queryable)
- `outlets` (Queryable)
- `lastModified` (Queryable)

### Security:
- Private Database (user's personal data)
- No public sharing required

## Setup Instructions:

1. **Enable CloudKit in Xcode:**
   - Select your app target
   - Go to "Signing & Capabilities"
   - Click "+ Capability"
   - Add "CloudKit"
   - Select "CloudKit" container

2. **Configure CloudKit Dashboard:**
   - Go to https://icloud.developer.apple.com/dashboard/
   - Select your app
   - Go to "Schema" tab
   - Add the "Spot" record type with the fields listed above

3. **Test CloudKit:**
   - Use the CloudKit sync view in the app
   - Check CloudKit Dashboard for uploaded records
   - Test on multiple devices with the same iCloud account

## Notes:
- All fields are optional except for basic location data
- Timestamps are used for conflict resolution
- Local ID helps track Core Data objects
- Private database ensures user data privacy
