

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
    @State private var selectedRoadType: RoadType = .paved
    @State private var showingDeadEnds = false
    @State private var showingDirtRoads = true
    @State private var showingInterstateRoads = true
    @State private var showingPavedRoads = true
    @State private var showingCities = true
    @State private var newRoadPoints: [(Double, Double)] = []
    @State private var newRoadName: String = ""
    @State private var isCreatingRoad = false
    @State private var showingNewRoadDialog = false
    @State private var showingDeleteConfirmation = false
    @State private var roadToDelete: String?
    @State private var showingExtractDialog = false
    
    enum EditMode: String, CaseIterable {
        case select = "Select"
        case addPoint = "Add Point"
        case deletePoint = "Delete Point"
        case movePoint = "Move Point"
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
                        Text("Add Road").tag(EditMode.addRoad)
                        Text("Delete Road").tag(EditMode.deleteRoad)
                        Text("Move Road").tag(EditMode.moveRoad)
                        Text("Add City").tag(EditMode.addCity)
                        Text("Move City").tag(EditMode.moveCity)
                        Text("Delete City").tag(EditMode.deleteCity)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                    
                    // Road Type Selector (shown when relevant)
                    if [.addRoad, .moveRoad].contains(editMode) {
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
                        Section("Interstate Routes") {
                            ForEach(dataManager.sortedRouteNames, id: \.self) { routeName in
                                HStack {
                                    Text(routeName)
                                    Spacer()
                                    Text("\(dataManager.interstateRoutes[routeName]?.count ?? 0) pts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if dataManager.deadEndRoutes.contains(routeName) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .help("Dead end route")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(SidebarListStyle())
                    
                    Divider()
                    
                    // Info Panel
                    if let route = selectedRoute,
                       let routeData = dataManager.interstateRoutes[route] {
                        RouteInfoPanel(
                            routeName: route,
                            routeData: routeData,
                            connections: dataManager.connections[route] ?? [],
                            onDelete: { confirmDeleteRoad(route) },
                            onExtract: { extractRoad() }
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
                        HStack {
                            Button(action: { dataManager.findDeadEnds() }) {
                                Image(systemName: "exclamationmark.triangle")
                            }
                            .help("Find Dead Ends")
                            
                            Button(action: { dataManager.autoConnectRoutes() }) {
                                Image(systemName: "link")
                            }
                            .help("Auto Connect")
                            
                            Button(action: { dataManager.validateData() }) {
                                Image(systemName: "checkmark.shield")
                            }
                            .help("Validate")
                        }
                        
                        // Delete All Actions
                        BulkActionsView(dataManager: dataManager)
                    }
                }
                .padding()
                
                Divider()
                
                // Statistics
                VStack(alignment: .leading) {
                    Text("Statistics")
                        .font(.headline)
                    Text("Interstate Routes: \(dataManager.interstateRoutes.count)")
                    Text("Paved Routes: \(dataManager.pavedRoutes.count)")
                    Text("Dirt Routes: \(dataManager.dirtRoutes.count)")
                    Text("Cities: \(dataManager.majorCities.count)")
                    Text("Dead Ends: \(dataManager.deadEndRoutes.count)")
                    Text("Paved Connections: \(dataManager.pavedRoadCount)")
                    Text("Dirt Connections: \(dataManager.dirtRoadCount)")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
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
                showingDeadEnds: $showingDeadEnds,
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
                    Toggle("Highlight Dead Ends", isOn: $showingDeadEnds)
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
                    dataManager.deleteRoute(roadName)
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
        .sheet(isPresented: $showingExtractDialog) {
            if let route = selectedRoute, let routeData = dataManager.interstateRoutes[route] {
                ExtractRoadView(
                    routeName: route,
                    routeData: routeData,
                    connections: dataManager.connections[route] ?? [],
                    onDismiss: { showingExtractDialog = false }
                )
            }
        }
        .onChange(of: editMode) { newMode in
            // Cancel road creation when switching modes
            if newMode != .addRoad && isCreatingRoad {
                cancelRoadCreation()
            }
        }
    }
}

struct RouteInfoPanel: View {
    let routeName: String
    let routeData: [(Double, Double)]
    let connections: [Connection]
    let onDelete: () -> Void
    let onExtract: () -> Void
    
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
                
                Button("Extract") {
                    onExtract()
                }
                .foregroundColor(.blue)
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

struct ExtractRoadView: View {
    let routeName: String
    let routeData: [(Double, Double)]
    let connections: [Connection]
    let onDismiss: () -> Void
    
    @State private var extractedData: String = ""
    @State private var showingExporter = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Extract Road Data")
                .font(.title2)
                .bold()
            
            Text(routeName)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text("\(routeData.count) waypoints")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Export Options:")
                    .font(.headline)
                
                HStack {
                    Button("Copy JSON") {
                        copyToClipboard()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save to File") {
                        showingExporter = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Copy Coordinates Only") {
                    copyCoordinatesOnly()
                }
                .buttonStyle(.bordered)
            }
            
            ScrollView {
                Text(generateJSONData())
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(height: 200)
            
            HStack {
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .fileExporter(
            isPresented: $showingExporter,
            document: TextDocument(content: generateJSONData()),
            contentType: .json,
            defaultFilename: "\(routeName).json"
        ) { result in
            // Handle save result if needed
        }
    }
    
    private func generateJSONData() -> String {
        let roadData: [String: Any] = [
            "routeName": routeName,
            "coordinates": routeData.map { [$0.0, $0.1] },
            "connections": connections.map { connection in
                [
                    "to": connection.to,
                    "distance": connection.distance,
                    "type": connection.type,
                    "fromPoint": connection.fromPoint ?? [],
                    "toPoint": connection.toPoint ?? []
                ]
            }
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: roadData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "Error generating JSON"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generateJSONData(), forType: .string)
    }
    
    private func copyCoordinatesOnly() {
        let coordinates = routeData.map { "[\($0.0), \($0.1)]" }.joined(separator: ",\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("[\n\(coordinates)\n]", forType: .string)
    }
}

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }
    
    var content: String
    
    init(content: String) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        content = ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: content.data(using: .utf8) ?? Data())
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
    
    func extractRoad() {
        guard selectedRoute != nil else { return }
        showingExtractDialog = true
    }
}

struct BulkActionsView: View {
    @ObservedObject var dataManager: DataManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Bulk Actions")
                .font(.headline)
                .foregroundColor(.red)
            
            VStack(spacing: 4) {
                HStack {
                    Button("Delete All Dirt Roads") {
                        dataManager.removeAllDirtRoads()
                    }
                    .foregroundColor(.orange)
                    .help("Remove all dirt road connections")
                    
                    Button("Delete All Paved Roads") {
                        dataManager.removeAllPavedRoads()
                    }
                    .foregroundColor(.blue)
                    .help("Remove all paved road connections")
                }
                
                Button("Delete All Interstate Roads") {
                    dataManager.removeAllInterstateRoutes()
                }
                .foregroundColor(.red)
                .help("⚠️ Remove all interstate routes")
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}

