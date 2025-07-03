# Interstate Map Editor

A comprehensive map editor for the Interstate game that allows you to edit route data and city locations.

## Features

- **Full-size macOS application** with interactive map view
- **Route Editing**:
  - Add, move, and delete waypoints on interstate routes
  - Select routes from the sidebar to edit them
  - Visual highlighting of selected routes and dead ends
- **City Management**:
  - Edit city names, locations, and population data
  - Add new cities or delete existing ones
  - Cities shown as purple markers on the map
- **Connection Management**:
  - Remove all dirt road connections with one click
  - Auto-connect nearby route endpoints
  - Visual display of connections (orange dashed = dirt, blue = paved)
- **Data Validation**:
  - Identify dead-end routes (routes with no connections)
  - Validate data integrity before saving
  - Highlight problematic routes in orange

## Building and Running

### Option 1: Using Swift Package Manager
```bash
cd InterstateMapEditor
swift build
swift run
```

### Option 2: Using Xcode
1. Open Terminal and navigate to the InterstateMapEditor directory
2. Run: `open Package.swift`
3. Xcode will open - click the Run button

## Usage

### Loading Data
1. Launch the app
2. Go to File → Open Interstate Data... (or press ⌘O)
3. Select your `interstate_routes_ACTUALLY_FIXED.json` file
4. The app will automatically look for `major_cities.json` in the same directory
5. If not found, it will prompt you to select it

### Editing Routes
1. Select a route from the sidebar
2. Choose an edit mode from the top toolbar:
   - **Select**: Click to select routes, points, or cities
   - **Add Point**: Click on a route to add a new waypoint
   - **Delete Point**: Click on waypoints to delete them
   - **Move Point**: Drag waypoints to new positions

### Editing Cities
1. Click on a city marker on the map
2. The city info panel will appear in the sidebar
3. Click "Edit" to modify the city data
4. Click "Save" when done, or "Delete City" to remove it

### Removing Dirt Roads
- Click the "Remove Dirt Roads" button in the toolbar
- This removes all connections with type "dirt" from the data
- The change is immediate but not saved until you save the file

### Finding Dead Ends
- Click "Find Dead Ends" in the toolbar
- Routes without any connections will be highlighted in orange
- You can then manually connect them or delete them

### Auto-Connecting Routes
- Click "Auto Connect" in the toolbar
- The editor will find route endpoints within 50km of each other
- It creates "paved" type connections between them

### Saving Changes
- Press ⌘S or go to File → Save Interstate Data
- The JSON files will be saved with proper formatting
- A save indicator shows when you have unsaved changes

## Map Controls

- **Pan**: Click and drag
- **Zoom**: Scroll or pinch
- **Select**: Click on routes, points, or cities
- **Toggle Overlays**: Use the checkboxes in the top-right:
  - "Show Dirt Roads" - Toggle dirt/paved connections
  - "Highlight Dead Ends" - Show problematic routes

## Data Format

The editor works with two JSON files:

### interstate_routes_ACTUALLY_FIXED.json
```json
{
  "interstateRoutes": {
    "I-5": [[lat, lon], [lat, lon], ...],
    ...
  },
  "connections": {
    "I-5": [
      {
        "to": "I-10",
        "distance": 12.5,
        "type": "paved",
        "from_point": [lat, lon],
        "to_point": [lat, lon]
      }
    ]
  }
}
```

### major_cities.json
```json
{
  "majorCities": [
    {
      "name": "Los Angeles, CA",
      "latitude": 34.0522,
      "longitude": -118.2437,
      "population": 3990456
    }
  ]
}
```

## Troubleshooting

- **Can't see routes**: Make sure you've loaded the correct JSON file
- **Changes not saving**: Check file permissions and ensure you pressed ⌘S
- **Performance issues**: The editor may slow down with very detailed routes. Consider simplifying routes with many points.

## Tips

- Start by removing all dirt roads, as they're problematic
- Use "Find Dead Ends" to identify disconnected routes
- The Auto-Connect feature works best for routes that almost meet
- Always validate data before saving to ensure integrity
- Keep backups of your JSON files before making major changes 