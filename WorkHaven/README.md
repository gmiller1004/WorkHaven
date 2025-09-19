# WorkHaven

A SwiftUI app for discovering and managing work-friendly spots with WiFi ratings, noise levels, and amenities.

## Project Structure

```
WorkHaven/
├── Models/
│   ├── Spot+CoreDataClass.swift      # Core Data class for Spot entity
│   ├── Spot+CoreDataProperties.swift # Core Data properties and fetch request
│   └── SpotModel.swift              # Spot extensions and utilities
├── Views/
│   ├── SpotListView.swift           # Main list view with search and filters
│   ├── SpotDetailView.swift         # Detailed view of a single spot
│   ├── AddSpotView.swift            # Form to add new spots
│   └── EditSpotView.swift           # Form to edit existing spots
├── ViewModels/
│   └── SpotViewModel.swift          # Business logic and data management
├── Services/
│   ├── LocationService.swift        # Location and distance calculations
│   └── PhotoService.swift          # Photo management utilities
└── WorkHaven.xcdatamodeld/         # Core Data model
```

## Core Data Model

### Spot Entity
- **name** (String, required): Name of the work spot
- **address** (String, required): Physical address
- **latitude** (Double, required): GPS latitude coordinate
- **longitude** (Double, required): GPS longitude coordinate
- **wifiRating** (Int16, required): WiFi quality rating (1-5 stars)
- **noiseRating** (String, required): Noise level ('Low', 'Medium', 'High')
- **outlets** (Bool, required): Whether power outlets are available
- **tips** (String, optional): Additional tips and notes
- **photoURL** (String, optional): URL to spot photo

## Features

- **Spot Management**: Add, edit, and delete work spots
- **Search & Filter**: Search by name, address, or tips; filter by noise level, WiFi rating, and amenities
- **Location Services**: Get current location and calculate distances
- **Ratings System**: 5-star WiFi rating and noise level classification
- **Map Integration**: View spot locations on a map
- **Photo Support**: Optional photo URLs for spots

## Usage

1. **Viewing Spots**: The main view shows a list of all spots with basic information
2. **Adding Spots**: Tap the + button to add new spots with all required information
3. **Editing Spots**: Tap on a spot to view details, then tap "Edit" to modify
4. **Searching**: Use the search bar to find spots by name, address, or tips
5. **Filtering**: Use the filter menu to show spots by noise level

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Dependencies

- SwiftUI
- Core Data
- Core Location
- MapKit
