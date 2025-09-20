# WorkHaven - Complete App Documentation

## Overview

WorkHaven is a comprehensive SwiftUI app for discovering, managing, and navigating to work-friendly spots. The app features a cozy coffee shop-inspired theme and provides detailed information about WiFi quality, noise levels, amenities, and user ratings for each location.

## 🎨 Design Theme

### Coffee Shop Aesthetic
- **Primary Color**: Mocha Brown (#8B5E3C)
- **Secondary Color**: Latte Beige (#FFF8E7)
- **Background**: Light Cream (#F5E9D8)
- **Accent**: Soft Coral (#F28C38)
- **Typography**: Avenir Next (rounded, friendly sans-serif)
- **Corner Radius**: Soft, rounded edges (6-60pt)
- **Shadows**: Subtle depth effects

## 📱 App Structure

### Main Navigation (TabView)
1. **Spots** - List view of all work spots
2. **Search** - Advanced search and filtering
3. **Map** - Interactive map with spot locations
4. **Import** - Data import and management
5. **More** - Settings and additional features

## 🏗️ Architecture

### Project Structure
```
WorkHaven/
├── Models/
│   ├── Spot+CoreDataClass.swift      # Core Data entity class
│   ├── Spot+CoreDataProperties.swift # Core Data properties
│   └── UserRating+CoreDataClass.swift # User rating entity
├── Views/
│   ├── ContentView.swift            # Main tab navigation
│   ├── SpotListView.swift           # List of all spots
│   ├── SpotDetailView.swift         # Detailed spot view
│   ├── SpotSearchView.swift         # Search and filter interface
│   ├── MapView.swift                # Interactive map
│   ├── ImportView.swift             # Data import management
│   ├── SettingsView.swift           # App settings
│   ├── AddSpotView.swift            # Add new spot form
│   ├── EditSpotView.swift           # Edit existing spot
│   ├── SpotCardView.swift           # Shareable spot card
│   ├── SpotShareView.swift          # Sharing interface
│   ├── UserRatingForm.swift         # User rating form
│   ├── AverageRatingsView.swift     # Community ratings display
│   └── CloudKitSyncView.swift       # CloudKit sync status
├── ViewModels/
│   └── SpotViewModel.swift          # Business logic and data management
├── Services/
│   ├── DataImporter.swift           # CSV data import service
│   ├── CloudKitManager.swift        # CloudKit synchronization
│   ├── NotificationManager.swift    # Push notifications
│   ├── LocationService.swift        # Location and distance calculations
│   └── ThemeManager.swift           # Design system and theming
├── WorkHaven.xcdatamodeld/          # Core Data model
└── WorkHaven.entitlements           # App capabilities
```

## 🗄️ Data Models

### Core Data Entities

#### Spot Entity
- **name** (String, required): Spot name
- **address** (String, required): Physical address
- **latitude** (Double, required): GPS latitude
- **longitude** (Double, required): GPS longitude
- **wifiRating** (Int16, required): WiFi quality (1-5 stars)
- **noiseRating** (String, required): Noise level ('Low', 'Medium', 'High')
- **outlets** (Bool, required): Power outlet availability
- **tips** (String, optional): Additional tips and notes
- **photoURL** (String, optional): Photo URL
- **cloudKitRecordID** (String, optional): CloudKit sync identifier
- **lastModified** (Date, optional): Last modification timestamp

#### UserRating Entity
- **wifiRating** (Int16, required): User's WiFi rating (1-5)
- **noiseRating** (String, required): User's noise rating
- **outlets** (Bool, required): User's outlet assessment
- **tips** (String, optional): User's tips
- **spot** (Spot, required): Relationship to Spot entity

## ✨ Key Features

### 1. Spot Management
- **Add Spots**: Create new work spots with all details
- **Edit Spots**: Modify existing spot information
- **Delete Spots**: Remove spots from the database
- **Photo Support**: Optional photo URLs for visual reference

### 2. Search & Discovery
- **Text Search**: Search by name, address, or tips
- **Advanced Filters**:
  - WiFi Rating (1-5 stars)
  - Noise Level (Low/Medium/High)
  - Outlet Availability (Yes/No)
- **Real-time Results**: Instant filtering as you type

### 3. Interactive Map
- **Map View**: Visual representation of all spots
- **Location Services**: Current location detection
- **Spot Annotations**: Clickable pins for each spot
- **Navigate to Spot**: Direct Apple Maps integration with driving directions

### 4. Community Features
- **User Ratings**: Anonymous rating system for each spot
- **Community Tips**: User-generated tips and experiences
- **Average Ratings**: Aggregated community feedback
- **Rating Form**: Easy-to-use rating interface

### 5. Data Import & Management
- **CSV Import**: Import spots from CSV files
- **Multi-City Support**: Boise, Seattle, and more cities
- **Data Validation**: Coordinate and data validation
- **Deduplication**: Automatic duplicate prevention
- **Clear All Data**: Complete data reset functionality

### 6. Cloud Synchronization
- **CloudKit Integration**: Sync across all user devices
- **Automatic Sync**: Background synchronization
- **Conflict Resolution**: Smart merge of conflicting data
- **Offline Support**: Works without internet connection

### 7. Push Notifications
- **New Spot Alerts**: Notifications for new spots in your area
- **Hot Spot Notifications**: Alerts for highly-rated locations
- **Location-Based**: Radius-based notification system
- **User Preferences**: Customizable notification settings

### 8. Sharing & Social
- **Spot Cards**: Beautiful, shareable spot cards
- **Social Sharing**: Share to iMessage, Instagram, X, etc.
- **Image Generation**: High-quality spot card images
- **Challenge Prompts**: "Share your new spot!" encouragement

## 🛠️ Technical Implementation

### Core Technologies
- **SwiftUI**: Modern declarative UI framework
- **Core Data**: Local data persistence
- **CloudKit**: Cloud synchronization
- **MapKit**: Maps and location services
- **Core Location**: GPS and location services
- **UserNotifications**: Push notification system

### Design System
- **ThemeManager**: Centralized design tokens
- **Dynamic Type**: Accessibility font scaling
- **VoiceOver**: Screen reader support
- **Color System**: Semantic color naming
- **Typography**: Consistent font hierarchy

### Data Flow
1. **Local Storage**: Core Data for offline access
2. **Cloud Sync**: CloudKit for cross-device synchronization
3. **Import System**: CSV parsing and validation
4. **Notification System**: Location-based alerts
5. **Sharing System**: Native iOS sharing integration

## 🔧 Configuration

### Required Setup
1. **Xcode Project**: iOS 17.6+ deployment target
2. **CloudKit**: iCloud container configuration
3. **Location Services**: Privacy usage descriptions
4. **Push Notifications**: APNs configuration

### Entitlements
- **CloudKit**: `iCloud.com.nextsizzle.WorkHaven`
- **Background Processing**: GPU-accelerated background tasks
- **Push Notifications**: Development environment

## 📊 Data Sources

### Built-in Data
- **Boise Work Spots**: 20+ local coffee shops and co-working spaces
- **Seattle Work Spots**: 20+ Seattle-area work locations
- **CSV Format**: Standardized data import format

### Data Fields
- Name, City, WiFi Rating, Noise Rating
- Photo URL, Latitude, Longitude
- Comprehensive spot information

## 🚀 Getting Started

### For Users
1. **Launch App**: Open WorkHaven on your device
2. **Browse Spots**: Explore the list or map view
3. **Search & Filter**: Find spots matching your preferences
4. **Rate Spots**: Share your experiences
5. **Navigate**: Get directions to your chosen spot

### For Developers
1. **Clone Repository**: `git clone https://github.com/gmiller1004/WorkHaven.git`
2. **Open in Xcode**: Open `WorkHaven.xcodeproj`
3. **Configure CloudKit**: Set up your CloudKit container
4. **Build & Run**: Deploy to simulator or device

## 🔮 Future Enhancements

### Planned Features
- **Favorites System**: Save preferred spots
- **Offline Maps**: Download maps for offline use
- **Social Features**: Follow other users' recommendations
- **Advanced Analytics**: Usage statistics and insights
- **Multi-Language**: Internationalization support

### Technical Improvements
- **Swift 6**: Full concurrency compliance
- **iOS 18**: Latest iOS features and APIs
- **Performance**: Optimized rendering and data loading
- **Accessibility**: Enhanced VoiceOver support

## 📝 Version History

### Current Version
- **Coffee Shop Theme**: Warm, cozy aesthetic
- **Navigate to Spot**: Apple Maps integration
- **CloudKit Sync**: Cross-device synchronization
- **Push Notifications**: Location-based alerts
- **Community Ratings**: User feedback system

### Previous Versions
- Initial SwiftUI implementation
- Core Data integration
- Basic map functionality
- CSV import system

## 🤝 Contributing

### Development Guidelines
- Follow SwiftUI best practices
- Maintain coffee shop theme consistency
- Ensure accessibility compliance
- Write comprehensive tests
- Document all public APIs

### Code Style
- Use Swift naming conventions
- Implement proper error handling
- Follow MVVM architecture pattern
- Maintain clean, readable code

---

**WorkHaven** - Your perfect work spot discovery companion ☕️✨

*Built with ❤️ using SwiftUI and Core Data*
