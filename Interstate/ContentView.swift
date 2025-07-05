
import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedRoute: String?
    @State private var selectedCity: MajorCity?
    @State private var selectedPointIndex: Int?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
        span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50)
    )
    @State private var editMode: EditMode = .select
    @State private var selectedRoadType: RoadType = .interstate
    @State private var showingDirtRoads = true
    @State private var showingInterstateRoads = true
    @State private var showingPavedRoads = true
    @State private var showingCities = true
    
    // Interstate-to-Interstate connection state
    @State private var fromInterstateRoute: String = ""
    @State private var toInterstateRoute: String = ""
    @State private var simplificationTolerance = 0.005 // Default to Medium (500m)
    
    // UI Section Expansion States
    @State private var showAutoConnect = false
    @State private var showSimplifyRoutes = false
    @State private var showBulkActions = false
    @State private var newRoadPoints: [(Double, Double)] = []
    @State private var newRoadName: String = ""
    @State private var isCreatingRoad = false
    @State private var showingNewRoadDialog = false
    @State private var showingDeleteConfirmation = false
    @State private var roadToDelete: String?
    
    enum EditMode: String, CaseIterable {
        case select = "Select"
        case addPoint = "Add Point"
        case deletePoint = "Delete Point"
        case movePoint = "Move Point"
        case extendRoad = "Extend Road"
        case addRoad = "Add Road"
        case deleteRoad = "Delete Road"
        case moveRoad = "Move Road"
        case addCity = "Add City"
        case moveCity = "Move City"
        case deleteCity = "Delete City"
    }
    
    enum RoadType: String, CaseIterable {
        case interstate = "Interstate"
        case paved = "Paved"
        case dirt = "Dirt"
    }
    
    // Computed property to get routes based on selected type
    var routesForSelectedType: [String: [(Double, Double)]] {
        switch selectedRoadType {
        case .interstate:
            return dataManager.interstateRoutes
        case .paved:
            return dataManager.pavedRoutes
        case .dirt:
            return dataManager.dirtRoutes
        }
    }
    
    var sortedRouteNamesForSelectedType: [String] {
        return routesForSelectedType.keys.sorted { route1, route2 in
            // Extract the numeric part for proper sorting
            let num1 = Int(route1.replacingOccurrences(of: "I-", with: "").components(separatedBy: " ").first ?? "") ?? 999
            let num2 = Int(route2.replacingOccurrences(of: "I-", with: "").components(separatedBy: " ").first ?? "") ?? 999
            return num1 < num2
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Professional Edit Mode Interface
                VStack(spacing: 12) {
                    Text("Edit Mode")
                        .font(.headline)
                    
                    // Main Edit Mode Selector
                                    Picker("Edit Mode", selection: $editMode) {
                        Text("Select").tag(EditMode.select)
                        Text("Add Point").tag(EditMode.addPoint)
                        Text("Delete Point").tag(EditMode.deletePoint)
                        Text("Move Point").tag(EditMode.movePoint)
                        Text("Extend Road").tag(EditMode.extendRoad)
                        Text("Add Road").tag(EditMode.addRoad)
                        Text("Delete Road").tag(EditMode.deleteRoad)
                        Text("Move Road").tag(EditMode.moveRoad)
                        Text("Add City").tag(EditMode.addCity)
                        Text("Move City").tag(EditMode.moveCity)
                        Text("Delete City").tag(EditMode.deleteCity)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                    
                    // Road Type Selector (shown for all road operations)
                    if [.select, .addPoint, .deletePoint, .movePoint, .extendRoad, .addRoad, .deleteRoad, .moveRoad].contains(editMode) {
                        HStack {
                            Text("Road Type:")
                                .font(.subheadline)
                            Picker("Road Type", selection: $selectedRoadType) {
                                Text("Interstate").tag(RoadType.interstate)
                                Text("Paved").tag(RoadType.paved)
                                Text("Dirt").tag(RoadType.dirt)
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
                
                // Data Loading Section (when no data)
                if !dataManager.isDataLoaded {
                    VStack(spacing: 12) {
                        Text("No Data Loaded")
                            .font(.headline)
                        Text("Load your interstate routes and cities data to begin editing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Load Data Files") {
                            dataManager.loadData()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    Spacer()
                } else {
                    // Edit Mode Status
                    if editMode == .addRoad {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Creating New Road")
                                .font(.headline)
                                .foregroundColor(.blue)
                            if isCreatingRoad {
                                Text("Points added: \(newRoadPoints.count)")
                                    .font(.caption)
                                Text("Click map to add points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Button("Finish Road") {
                                        finishCreatingRoad()
                                    }
                                    .disabled(newRoadPoints.count < 2)
                                    Button("Cancel") {
                                        cancelRoadCreation()
                                    }
                                    .foregroundColor(.red)
                                }
                            } else {
                                Text("Click map to start new road")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else if editMode == .addCity {
                        VStack(alignment: .leading) {
                            Text("Add City Mode")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Text("Click map to add a new city")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else if editMode == .deleteRoad {
                        VStack(alignment: .leading) {
                            Text("Delete Road Mode")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text("Click a road on the map to delete it")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("⚠️ This action cannot be undone")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else if editMode == .moveCity {
                        VStack(alignment: .leading) {
                            Text("Move City Mode")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Text("Click and drag cities to move them")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else if editMode == .deleteCity {
                        VStack(alignment: .leading) {
                            Text("Delete City Mode")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text("Click a city on the map to delete it")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("⚠️ This action cannot be undone")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else if editMode == .extendRoad {
                        VStack(alignment: .leading) {
                            Text("Extend Road Mode")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("Click near a road endpoint to extend it")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Select a road and road type above, then click near either end")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("✅ No more spikes - guaranteed road extension!")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else if editMode == .moveRoad {
                        VStack(alignment: .leading) {
                            Text("Move Road Points")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("Click and drag road endpoints to move them")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Select road type above to specify which roads to move")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    // Route List
                    List(selection: $selectedRoute) {
                        Section("\(selectedRoadType.rawValue) Routes") {
                            ForEach(sortedRouteNamesForSelectedType, id: \.self) { routeName in
                                HStack {
                                    Text(routeName)
                                    Spacer()
                                    Text("\(routesForSelectedType[routeName]?.count ?? 0) pts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(SidebarListStyle())
                    
                    Divider()
                    
                    // Info Panel
                    if let route = selectedRoute,
                       let routeData = routesForSelectedType[route] {
                        RouteInfoPanel(
                            routeName: route,
                            routeData: routeData,
                            connections: dataManager.connections[route] ?? [],
                            onDelete: { confirmDeleteRoad(route) },
                            onDeselect: { selectedRoute = nil }
                        )
                        .padding()
                    } else if let city = selectedCity {
                        CityInfoPanel(city: city, dataManager: dataManager, selectedCity: $selectedCity)
                            .padding()
                    }
                    
                    Spacer()
                }
                
                // Actions (always visible)
                VStack(spacing: 8) {
                    if dataManager.isDataLoaded {
                        Button(action: { 
                            dataManager.saveData() 
                            // Show brief feedback
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // Could add a toast notification here if needed
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text(dataManager.hasUnsavedChanges ? "Save Changes" : "Saved ✓")
                            }
                        }
                        .disabled(!dataManager.hasUnsavedChanges)
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Load Data Files") {
                            dataManager.loadData()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if dataManager.isDataLoaded {

                        
                        // Auto-Connect Tools
                        VStack(spacing: 0) {
                            Button(action: { showAutoConnect.toggle() }) {
                                HStack {
                                    Image(systemName: showAutoConnect ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Auto-Connect")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showAutoConnect {
                                VStack(spacing: 6) {
                                    VStack(spacing: 2) {
                                        Button("Paved → Interstate") {
                                            dataManager.autoConnectPavedToInterstate()
                                        }
                                        .font(.caption)
                                        .help("Move paved road endpoints to nearest interstate points")
                                        .foregroundColor(.blue)
                                        
                                        Button("Dirt → Interstate") {
                                            dataManager.autoConnectDirtToInterstate()
                                        }
                                        .font(.caption)
                                        .help("Move dirt road endpoints to nearest interstate points")
                                        .foregroundColor(.orange)
                                    }
                                    
                                    Divider()
                                    
                                    // Interstate-to-Interstate Connection
                                    VStack(spacing: 4) {
                                        Text("Interstate ↔ Interstate")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .bold()
                                        
                                        VStack(spacing: 2) {
                                            Picker("From", selection: $fromInterstateRoute) {
                                                Text("Select From Route").tag("")
                                                ForEach(dataManager.sortedRouteNames, id: \.self) { route in
                                                    Text(route).tag(route)
                                                }
                                            }
                                            .pickerStyle(MenuPickerStyle())
                                            .font(.caption)
                                            .disabled(!dataManager.isDataLoaded || dataManager.interstateRoutes.count < 2)
                                            
                                            Picker("To", selection: $toInterstateRoute) {
                                                Text("Select To Route").tag("")
                                                ForEach(dataManager.sortedRouteNames.filter { $0 != fromInterstateRoute }, id: \.self) { route in
                                                    Text(route).tag(route)
                                                }
                                            }
                                            .pickerStyle(MenuPickerStyle())
                                            .font(.caption)
                                            .disabled(!dataManager.isDataLoaded || dataManager.interstateRoutes.count < 2)
                                            
                                            Button("Connect Routes") {
                                                dataManager.autoConnectInterstateToInterstate(fromRoute: fromInterstateRoute, toRoute: toInterstateRoute)
                                                // Reset selections after connection
                                                fromInterstateRoute = ""
                                                toInterstateRoute = ""
                                            }
                                            .font(.caption)
                                            .disabled(!dataManager.isDataLoaded || 
                                                     fromInterstateRoute.isEmpty || 
                                                     toInterstateRoute.isEmpty || 
                                                     fromInterstateRoute == toInterstateRoute ||
                                                     dataManager.interstateRoutes.count < 2)
                                            .help("Move \(fromInterstateRoute.isEmpty ? "selected" : fromInterstateRoute) endpoint to nearest point on \(toInterstateRoute.isEmpty ? "selected" : toInterstateRoute)")
                                            .foregroundColor(.green)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                        
                        // Route Simplification Tools
                        VStack(spacing: 0) {
                            Button(action: { showSimplifyRoutes.toggle() }) {
                                HStack {
                                    Image(systemName: showSimplifyRoutes ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Simplify Routes")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showSimplifyRoutes {
                                VStack(spacing: 6) {
                                    VStack(spacing: 4) {
                                        Text("Tolerance")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Picker("Tolerance", selection: $simplificationTolerance) {
                                            Text("High (100m)").tag(0.001)
                                            Text("Medium (500m)").tag(0.005)
                                            Text("Low (1km)").tag(0.01)
                                            Text("Very Low (5km)").tag(0.05)
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .font(.caption)
                                    }
                                    
                                    VStack(spacing: 2) {
                                        Button("Simplify Selected Route") {
                                            guard let selectedRoute = selectedRoute else { return }
                                            let roadType = selectedRoadType.rawValue.lowercased()
                                            dataManager.simplifyRoute(selectedRoute, roadType: roadType, tolerance: simplificationTolerance)
                                        }
                                        .font(.caption)
                                        .disabled(selectedRoute == nil)
                                        .help("Remove unnecessary points from the selected route")
                                        .foregroundColor(.purple)
                                        
                                        Button("Simplify All \(selectedRoadType.rawValue)") {
                                            let roadType = selectedRoadType.rawValue.lowercased()
                                            dataManager.simplifyAllRoutes(roadType: roadType, tolerance: simplificationTolerance)
                                        }
                                        .font(.caption)
                                        .disabled(!dataManager.isDataLoaded)
                                        .help("Remove unnecessary points from all \(selectedRoadType.rawValue.lowercased()) routes")
                                        .foregroundColor(.purple)
                                    }
                                }
                                .padding(8)
                                .background(Color.purple.opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                        
                        // Bulk Actions
                        VStack(spacing: 0) {
                            Button(action: { showBulkActions.toggle() }) {
                                HStack {
                                    Image(systemName: showBulkActions ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Bulk Actions")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showBulkActions {
                                BulkActionsView(dataManager: dataManager)
                                    .padding(8)
                                    .background(Color.red.opacity(0.05))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
                
                Divider()
                
                // Statistics
                VStack(alignment: .leading, spacing: 4) {
                    Text("Statistics")
                        .font(.headline)
                    Text("Interstate Routes: \(dataManager.interstateRoutes.count)")
                    Text("Paved Routes: \(dataManager.pavedRoutes.count)")
                    Text("Dirt Routes: \(dataManager.dirtRoutes.count)")
                    Text("Cities: \(dataManager.majorCities.count)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .navigationSplitViewColumnWidth(min: 320, ideal: 350, max: 450)
        } detail: {
            // Map View
            MapEditorView(
                mapRegion: $mapRegion,
                selectedRoute: $selectedRoute,
                selectedCity: $selectedCity,
                selectedPointIndex: $selectedPointIndex,
                editMode: $editMode,
                showingDirtRoads: $showingDirtRoads,
                showingInterstateRoads: $showingInterstateRoads,
                showingPavedRoads: $showingPavedRoads,
                showingCities: $showingCities,
                selectedRoadType: $selectedRoadType,
                newRoadPoints: $newRoadPoints,
                isCreatingRoad: $isCreatingRoad,
                onDeleteRoad: { roadName in confirmDeleteRoad(roadName) }
            )
            .environmentObject(dataManager)
            .overlay(alignment: .topTrailing) {
                VStack {
                    Toggle("Show Interstate Roads", isOn: $showingInterstateRoads)
                    Toggle("Show Paved Roads (Blue)", isOn: $showingPavedRoads)
                    Toggle("Show Dirt Roads (Orange)", isOn: $showingDirtRoads)
                    Toggle("Show Cities (Purple)", isOn: $showingCities)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
                .padding()
            }
        }

        .sheet(isPresented: $showingNewRoadDialog) {
            VStack(spacing: 20) {
                Text("Name New Road")
                    .font(.title2)
                    .bold()
                
                TextField("Enter road name (e.g., I-95, US-1)", text: $newRoadName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if !newRoadName.isEmpty {
                            saveNewRoad()
                        }
                    }
                
                Text("Points: \(newRoadPoints.count)")
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Cancel") {
                        showingNewRoadDialog = false
                    }
                    .foregroundColor(.red)
                    
                    Button("Create Road") {
                        saveNewRoad()
                    }
                    .disabled(newRoadName.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 300)
        }
        .confirmationDialog("Delete Road", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete \(roadToDelete ?? "Road")", role: .destructive) {
                if let roadName = roadToDelete {
                    let roadType = selectedRoadType.rawValue.lowercased()
                    dataManager.deleteRoute(roadName, type: roadType)
                    if selectedRoute == roadName {
                        selectedRoute = nil
                    }
                }
                roadToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                roadToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete \(roadToDelete ?? "this road")? This action cannot be undone.")
        }

        .onChange(of: editMode) { newMode in
            // Cancel road creation when switching modes
            if newMode != .addRoad && isCreatingRoad {
                cancelRoadCreation()
            }
        }
        .onChange(of: dataManager.isDataLoaded) { isLoaded in
            // Reset interstate selections when data changes
            if isLoaded {
                fromInterstateRoute = ""
                toInterstateRoute = ""
            }
        }
    }
}

struct RouteInfoPanel: View {
    let routeName: String
    let routeData: [(Double, Double)]
    let connections: [Connection]
    let onDelete: () -> Void
    let onDeselect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(routeName)
                .font(.title2)
                .bold()
            
            Text("\(routeData.count) waypoints")
                .foregroundColor(.secondary)
            
            if !connections.isEmpty {
                Text("Connections:")
                    .font(.headline)
                    .padding(.top)
                
                ForEach(connections, id: \.to) { connection in
                    HStack {
                        Circle()
                            .fill(connection.type == "paved" ? Color.blue : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(connection.to)
                        Spacer()
                        Text(String(format: "%.1f km", connection.distance))
                            .font(.caption)
                        Text(connection.type)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Button("Delete") {
                    onDelete()
                }
                .foregroundColor(.red)
                
                Button("Deselect") {
                    onDeselect()
                }
                .foregroundColor(.gray)
            }
        }
    }
}

struct CityInfoPanel: View {
    let city: MajorCity
    @ObservedObject var dataManager: DataManager
    @Binding var selectedCity: MajorCity?
    @State private var editedName: String = ""
    @State private var editedLat: String = ""
    @State private var editedLon: String = ""
    @State private var editedPop: String = ""
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("City Information")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing()
                    }
                }
                if isEditing {
                    Button("Cancel") {
                        cancelEditing()
                    }
                    .foregroundColor(.gray)
                }
            }
            
            if isEditing {
                TextField("Name", text: $editedName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Latitude", text: $editedLat)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Longitude", text: $editedLon)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Population", text: $editedPop)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                Text(city.name)
                    .font(.title3)
                Text("Lat: \(city.latitude, specifier: "%.6f")")
                Text("Lon: \(city.longitude, specifier: "%.6f")")
                Text("Population: \(city.population)")
            }
            
            Divider()
            
            Button("Delete City") {
                dataManager.deleteCity(city)
                selectedCity = nil
            }
            .foregroundColor(.red)
        }
        .onAppear {
            // Reset editing state when city changes
            isEditing = false
        }
    }
    
    private func startEditing() {
        editedName = city.name
        editedLat = String(city.latitude)
        editedLon = String(city.longitude)
        editedPop = String(city.population)
        isEditing = true
    }
    
    private func cancelEditing() {
        isEditing = false
    }
    
    private func saveChanges() {
        if let lat = Double(editedLat),
           let lon = Double(editedLon),
           let pop = Int(editedPop) {
            dataManager.updateCity(
                city,
                name: editedName,
                latitude: lat,
                longitude: lon,
                population: pop
            )
        }
        isEditing = false
    }
}





// MARK: - New Road Creation Functions
extension ContentView {
    func finishCreatingRoad() {
        guard newRoadPoints.count >= 2 else { return }
        showingNewRoadDialog = true
    }
    
    func cancelRoadCreation() {
        newRoadPoints.removeAll()
        isCreatingRoad = false
        editMode = .select
    }
    
    func saveNewRoad() {
        guard !newRoadName.isEmpty, newRoadPoints.count >= 2 else { return }
        dataManager.addNewRoute(name: newRoadName, points: newRoadPoints, type: selectedRoadType.rawValue.lowercased())
        
        // Reset state
        newRoadPoints.removeAll()
        newRoadName = ""
        isCreatingRoad = false
        showingNewRoadDialog = false
        editMode = .select
    }
    
    func confirmDeleteRoad(_ roadName: String) {
        roadToDelete = roadName
        showingDeleteConfirmation = true
    }
}

struct BulkActionsView: View {
    @ObservedObject var dataManager: DataManager
    
    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 4) {
                HStack {
                    Button("Delete All Dirt Roads") {
                        dataManager.removeAllDirtRoads()
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .help("Remove all dirt road connections")
                    
                    Button("Delete All Paved Roads") {
                        dataManager.removeAllPavedRoads()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .help("Remove all paved road connections")
                }
                
                Button("Delete All Interstate Roads") {
                    dataManager.removeAllInterstateRoutes()
                }
                .font(.caption)
                .foregroundColor(.red)
                .help("⚠️ Remove all interstate routes")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
} 