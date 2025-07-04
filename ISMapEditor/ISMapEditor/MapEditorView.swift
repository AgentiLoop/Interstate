import SwiftUI
import MapKit

struct MapEditorView: NSViewRepresentable {
    @Binding var mapRegion: MKCoordinateRegion
    @Binding var selectedRoute: String?
    @Binding var selectedCity: MajorCity?
    @Binding var selectedPointIndex: Int?
    @Binding var editMode: ContentView.EditMode
    @Binding var showingDeadEnds: Bool
    @Binding var showingDirtRoads: Bool
    @Binding var showingInterstateRoads: Bool
    @Binding var showingPavedRoads: Bool
    @Binding var showingCities: Bool
    @Binding var selectedRoadType: ContentView.RoadType
    @Binding var newRoadPoints: [(Double, Double)]
    @Binding var isCreatingRoad: Bool
    @EnvironmentObject var dataManager: DataManager
    
    let onDeleteRoad: (String) -> Void
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsScale = true
        mapView.showsCompass = true
        
        // Add click gesture recognizer
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapClick(_:)))
        mapView.addGestureRecognizer(clickGesture)
        
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Only update map region if significantly different and not currently being set by user interaction
        if abs(mapView.region.center.latitude - mapRegion.center.latitude) > 1 ||
           abs(mapView.region.center.longitude - mapRegion.center.longitude) > 1 {
            // Only update if the map isn't currently being manipulated by the user
            if !context.coordinator.isUserInteracting {
                DispatchQueue.main.async {
                    mapView.setRegion(mapRegion, animated: true)
                }
            }
        }
        
        // Update overlays and annotations only when necessary
        updateMapContent(mapView)
    }
    
    private func updateMapContent(_ mapView: MKMapView) {
        // Store current region to restore it after updates
        let currentRegion = mapView.region
        
        // Clear existing
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // Add interstate route overlays
        if showingInterstateRoads {
        for (routeName, routeCoords) in dataManager.interstateRoutes {
            let coordinates = routeCoords.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
            let polyline = RoutePolyline(coordinates: coordinates, count: coordinates.count)
            polyline.routeName = routeName
                polyline.routeType = "interstate"
            polyline.isSelected = routeName == selectedRoute
            polyline.isDeadEnd = dataManager.deadEndRoutes.contains(routeName)
            mapView.addOverlay(polyline)
            
            // Add editable points for selected route
            if routeName == selectedRoute {
                for (index, coord) in routeCoords.enumerated() {
                    let annotation = RoutePointAnnotation()
                    annotation.coordinate = CLLocationCoordinate2D(latitude: coord.0, longitude: coord.1)
                    annotation.routeName = routeName
                    annotation.pointIndex = index
                    annotation.isSelected = index == selectedPointIndex
                    mapView.addAnnotation(annotation)
                    }
                }
            }
        }
        
        // Add paved route overlays
        if showingPavedRoads {
            for (routeName, routeCoords) in dataManager.pavedRoutes {
                let coordinates = routeCoords.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
                let polyline = RoutePolyline(coordinates: coordinates, count: coordinates.count)
                polyline.routeName = routeName
                polyline.routeType = "paved"
                polyline.isSelected = routeName == selectedRoute
                mapView.addOverlay(polyline)
                
                // Add editable points for selected route
                if routeName == selectedRoute {
                    for (index, coord) in routeCoords.enumerated() {
                        let annotation = RoutePointAnnotation()
                        annotation.coordinate = CLLocationCoordinate2D(latitude: coord.0, longitude: coord.1)
                        annotation.routeName = routeName
                        annotation.pointIndex = index
                        annotation.isSelected = index == selectedPointIndex
                        mapView.addAnnotation(annotation)
                    }
                }
            }
        }
        
        // Add dirt route overlays
        if showingDirtRoads {
            for (routeName, routeCoords) in dataManager.dirtRoutes {
                let coordinates = routeCoords.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
                let polyline = RoutePolyline(coordinates: coordinates, count: coordinates.count)
                polyline.routeName = routeName
                polyline.routeType = "dirt"
                polyline.isSelected = routeName == selectedRoute
                mapView.addOverlay(polyline)
                
                // Add editable points for selected route
                if routeName == selectedRoute {
                    for (index, coord) in routeCoords.enumerated() {
                        let annotation = RoutePointAnnotation()
                        annotation.coordinate = CLLocationCoordinate2D(latitude: coord.0, longitude: coord.1)
                        annotation.routeName = routeName
                        annotation.pointIndex = index
                        annotation.isSelected = index == selectedPointIndex
                        mapView.addAnnotation(annotation)
                    }
                }
            }
        }
        
        // Add connection overlays
            for (fromRoute, connections) in dataManager.connections {
                for connection in connections {
                // Skip if the connection type is not being shown
                if (connection.type == "dirt" && !showingDirtRoads) ||
                   (connection.type == "paved" && !showingPavedRoads) {
                    continue
                }
                    if let fromCoords = dataManager.interstateRoutes[fromRoute],
                       let toCoords = dataManager.interstateRoutes[connection.to] {
                        
                        let from: CLLocationCoordinate2D
                        let to: CLLocationCoordinate2D
                        
                        if let fromPoint = connection.fromPoint, let toPoint = connection.toPoint {
                            from = CLLocationCoordinate2D(latitude: fromPoint[0], longitude: fromPoint[1])
                            to = CLLocationCoordinate2D(latitude: toPoint[0], longitude: toPoint[1])
                        } else {
                            // Find closest endpoints
                            let endpoints1 = [fromCoords.first!, fromCoords.last!]
                            let endpoints2 = [toCoords.first!, toCoords.last!]
                            var minDist = Double.infinity
                            var bestFrom = endpoints1[0]
                            var bestTo = endpoints2[0]
                            
                            for ep1 in endpoints1 {
                                for ep2 in endpoints2 {
                                    let dist = dataManager.calculateDistance(from: ep1, to: ep2)
                                    if dist < minDist {
                                        minDist = dist
                                        bestFrom = ep1
                                        bestTo = ep2
                                    }
                                }
                            }
                            
                            from = CLLocationCoordinate2D(latitude: bestFrom.0, longitude: bestFrom.1)
                            to = CLLocationCoordinate2D(latitude: bestTo.0, longitude: bestTo.1)
                        }
                        
                        let connectionLine = ConnectionPolyline(coordinates: [from, to], count: 2)
                        connectionLine.connectionType = connection.type
                        mapView.addOverlay(connectionLine)
                        
                        // Add road endpoint annotations for move mode
                        let shouldShowMovePoints = editMode == .moveRoad && 
                            ((connection.type == "dirt" && selectedRoadType == .dirt && showingDirtRoads) ||
                             (connection.type == "paved" && selectedRoadType == .paved && showingPavedRoads))
                        
                        if shouldShowMovePoints {
                            if let fromPoint = connection.fromPoint, let toPoint = connection.toPoint {
                                // From point
                                let fromAnnotation = RoadPointAnnotation()
                                fromAnnotation.coordinate = CLLocationCoordinate2D(latitude: fromPoint[0], longitude: fromPoint[1])
                                fromAnnotation.connectionFrom = fromRoute
                                fromAnnotation.connectionTo = connection.to
                                fromAnnotation.connectionType = connection.type
                                fromAnnotation.isFromPoint = true
                                mapView.addAnnotation(fromAnnotation)
                                
                                // To point
                                let toAnnotation = RoadPointAnnotation()
                                toAnnotation.coordinate = CLLocationCoordinate2D(latitude: toPoint[0], longitude: toPoint[1])
                                toAnnotation.connectionFrom = fromRoute
                                toAnnotation.connectionTo = connection.to
                                toAnnotation.connectionType = connection.type
                                toAnnotation.isFromPoint = false
                                mapView.addAnnotation(toAnnotation)
                            }
                    }
                }
            }
        }
        
        // Add city annotations
        if showingCities {
        for city in dataManager.majorCities {
            let annotation = CityAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude)
            annotation.city = city
            annotation.title = city.name
            annotation.subtitle = "Pop: \(city.population)"
            mapView.addAnnotation(annotation)
            }
        }
        
        // Add dead end point annotations when highlighting is enabled
        if showingDeadEnds {
            for routeName in dataManager.deadEndRoutes {
                if let routeCoords = dataManager.interstateRoutes[routeName], !routeCoords.isEmpty {
                    // Add red annotations for the endpoints of dead end routes
                    let firstPoint = routeCoords.first!
                    let lastPoint = routeCoords.last!
                    
                    let firstAnnotation = DeadEndPointAnnotation()
                    firstAnnotation.coordinate = CLLocationCoordinate2D(latitude: firstPoint.0, longitude: firstPoint.1)
                    firstAnnotation.routeName = routeName
                    firstAnnotation.isEndpoint = true
                    firstAnnotation.title = "Dead End"
                    firstAnnotation.subtitle = routeName
                    mapView.addAnnotation(firstAnnotation)
                    
                    // Only add second annotation if it's different from the first
                    if firstPoint.0 != lastPoint.0 || firstPoint.1 != lastPoint.1 {
                        let lastAnnotation = DeadEndPointAnnotation()
                        lastAnnotation.coordinate = CLLocationCoordinate2D(latitude: lastPoint.0, longitude: lastPoint.1)
                        lastAnnotation.routeName = routeName
                        lastAnnotation.isEndpoint = true
                        lastAnnotation.title = "Dead End"
                        lastAnnotation.subtitle = routeName
                        mapView.addAnnotation(lastAnnotation)
                    }
                }
            }
        }
        
        // Add new road being created
        if isCreatingRoad && newRoadPoints.count >= 2 {
            let coordinates = newRoadPoints.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
            let polyline = NewRoadPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
        
        // Add new road points
        if isCreatingRoad {
            for (index, point) in newRoadPoints.enumerated() {
                let annotation = NewRoadPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: point.0, longitude: point.1)
                annotation.pointIndex = index
                mapView.addAnnotation(annotation)
            }
        }
        
        // Restore the region to prevent zooming out - commented out to prevent layout conflicts
        // Only restore if the difference is significant (to avoid conflicts with legitimate region changes)
        // if abs(mapView.region.center.latitude - currentRegion.center.latitude) > 0.01 ||
        //    abs(mapView.region.center.longitude - currentRegion.center.longitude) > 0.01 ||
        //    abs(mapView.region.span.latitudeDelta - currentRegion.span.latitudeDelta) > 0.01 ||
        //    abs(mapView.region.span.longitudeDelta - currentRegion.span.longitudeDelta) > 0.01 {
        //     mapView.setRegion(currentRegion, animated: false)
        // }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapEditorView
        var isUserInteracting = false
        
        init(_ parent: MapEditorView) {
            self.parent = parent
        }
        
        // Helper method to check if a route belongs to the selected road type
        private func isRouteOfSelectedType(_ routeName: String?) -> Bool {
            guard let routeName = routeName else { return false }
            
            switch parent.selectedRoadType {
            case .interstate:
                return parent.dataManager.interstateRoutes[routeName] != nil
            case .paved:
                return parent.dataManager.pavedRoutes[routeName] != nil
            case .dirt:
                return parent.dataManager.dirtRoutes[routeName] != nil
            }
        }
        
        // MARK: - Map Interaction
        
        @objc func handleMapClick(_ gesture: NSClickGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let clickPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(clickPoint, toCoordinateFrom: mapView)
            
            switch parent.editMode {
            case .addPoint:
                handleAddPoint(coordinate: coordinate, mapView: mapView)
            case .extendRoad:
                handleExtendRoad(coordinate: coordinate, mapView: mapView)
            case .addRoad:
                handleAddRoadPoint(coordinate: coordinate)
            case .addCity:
                handleAddCity(coordinate: coordinate)
            case .deleteRoad:
                handleDeleteRoad(at: clickPoint, mapView: mapView)
            case .deleteCity:
                handleDeleteCity(at: clickPoint, mapView: mapView)
            case .select:
                handleSelection(at: clickPoint, mapView: mapView)
            default:
                break
            }
        }
        
        private func handleAddPoint(coordinate: CLLocationCoordinate2D, mapView: MKMapView) {
            guard let route = parent.selectedRoute else { return }
            
            // Get route coordinates based on selected road type
            let routeCoords: [(Double, Double)]?
            switch parent.selectedRoadType {
            case .interstate:
                routeCoords = parent.dataManager.interstateRoutes[route]
            case .paved:
                routeCoords = parent.dataManager.pavedRoutes[route]
            case .dirt:
                routeCoords = parent.dataManager.dirtRoutes[route]
            }
            
            // SIMPLE ADD POINT: Only inserts between existing points (no extension)
            if let routeCoords = routeCoords {
                let clickPoint = (coordinate.latitude, coordinate.longitude)
                
                print("📍 ADD POINT: Inserting between existing points")
                
                var bestIndex = 1 // Default to after first point
                var minDistance = Double.infinity
                
                // Find closest line segment for insertion
                for i in 0..<max(0, routeCoords.count - 1) {
                    let p1 = routeCoords[i]
                    let p2 = routeCoords[i + 1]
                    
                    // Calculate distance from click to line segment
                    let dist = distanceFromPoint(clickPoint, toLineSegment: (p1, p2))
                    
                    if dist < minDistance {
                        minDistance = dist
                        bestIndex = i + 1
                    }
                }
                
                // Determine the road type for the addPoint method
                let roadType: String
                switch parent.selectedRoadType {
                case .interstate:
                    roadType = "interstate"
                case .paved:
                    roadType = "paved"
                case .dirt:
                    roadType = "dirt"
                }
                
                parent.dataManager.addPoint(
                    to: route,
                    at: bestIndex,
                    coordinate: clickPoint,
                    roadType: roadType
                )
            }
        }
        
        private func handleExtendRoad(coordinate: CLLocationCoordinate2D, mapView: MKMapView) {
            guard let route = parent.selectedRoute else {
                print("❌ EXTEND ROAD: No route selected!")
                return
            }
            
            // Get route coordinates based on selected road type
            let routeCoords: [(Double, Double)]?
            switch parent.selectedRoadType {
            case .interstate:
                routeCoords = parent.dataManager.interstateRoutes[route]
            case .paved:
                routeCoords = parent.dataManager.pavedRoutes[route]
            case .dirt:
                routeCoords = parent.dataManager.dirtRoutes[route]
            }
            
            guard let routeCoords = routeCoords, !routeCoords.isEmpty else {
                print("❌ EXTEND ROAD: Route has no coordinates!")
                return
            }
            
            let clickPoint = (coordinate.latitude, coordinate.longitude)
            
            // Check distances to endpoints
            let startPoint = routeCoords.first!
            let endPoint = routeCoords.last!
            
            let distanceToStart = parent.dataManager.calculateDistance(from: clickPoint, to: startPoint)
            let distanceToEnd = parent.dataManager.calculateDistance(from: clickPoint, to: endPoint)
            
            print("🚀 EXTEND ROAD: Click at (\(String(format: "%.6f", clickPoint.0)), \(String(format: "%.6f", clickPoint.1)))")
            print("   Distance to START: \(String(format: "%.1f", distanceToStart)) km")
            print("   Distance to END: \(String(format: "%.1f", distanceToEnd)) km")
            
            // Determine the road type for the addPoint method
            let roadType: String
            switch parent.selectedRoadType {
            case .interstate:
                roadType = "interstate"
            case .paved:
                roadType = "paved"
            case .dirt:
                roadType = "dirt"
            }
            
            // SIMPLE EXTENSION LOGIC: Always extend from the closest endpoint
            if distanceToStart <= distanceToEnd {
                // EXTEND FROM START
                print("🎯 EXTENDING FROM START (closest endpoint)")
                parent.dataManager.addPoint(
                    to: route,
                    at: 0,
                    coordinate: clickPoint,
                    roadType: roadType
                )
            } else {
                // EXTEND FROM END
                print("🎯 EXTENDING FROM END (closest endpoint)")
                parent.dataManager.addPoint(
                    to: route,
                    at: routeCoords.count,
                    coordinate: clickPoint,
                    roadType: roadType
                )
            }
        }
        
        private func handleSelection(at point: CGPoint, mapView: MKMapView) {
            // Check for annotation selection
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coordinate)
            let rect = MKMapRect(x: mapPoint.x - 10, y: mapPoint.y - 10, width: 20, height: 20)
            let annotations = mapView.annotations(in: rect)
            
            for annotation in annotations {
                if let cityAnnotation = annotation as? CityAnnotation {
                    parent.selectedCity = cityAnnotation.city
                    parent.selectedRoute = nil
                    return
                } else if let pointAnnotation = annotation as? RoutePointAnnotation {
                    // Only select if the route matches the selected road type
                    if isRouteOfSelectedType(pointAnnotation.routeName) {
                        parent.selectedRoute = pointAnnotation.routeName
                        parent.selectedPointIndex = pointAnnotation.pointIndex
                        parent.selectedCity = nil
                        return
                    }
                }
            }
            
            // Check for overlay selection - only consider roads of the selected type
            for overlay in mapView.overlays {
                if let polyline = overlay as? RoutePolyline,
                   isRouteOfSelectedType(polyline.routeName) {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    let polylinePoint = renderer.point(for: mapPoint)
                    
                    if renderer.path?.contains(polylinePoint) ?? false {
                        parent.selectedRoute = polyline.routeName
                        parent.selectedPointIndex = nil
                        parent.selectedCity = nil
                        return
                    }
                }
            }
            
            // Clear selection
            parent.selectedRoute = nil
            parent.selectedPointIndex = nil
            parent.selectedCity = nil
        }
        
        private func handleAddRoadPoint(coordinate: CLLocationCoordinate2D) {
            parent.newRoadPoints.append((coordinate.latitude, coordinate.longitude))
            if !parent.isCreatingRoad {
                parent.isCreatingRoad = true
            }
        }
        
        private func handleAddCity(coordinate: CLLocationCoordinate2D) {
            // Create a new city with default values
            let newCity = MajorCity(
                name: "New City",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                population: 10000
            )
            parent.dataManager.addCity(newCity)
            parent.selectedCity = newCity
            parent.editMode = .select
        }
        
        private func handleDeleteRoad(at point: CGPoint, mapView: MKMapView) {
            // Check for connection overlays first (individual connections)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coordinate)
            
            // First try to delete individual connections
            for overlay in mapView.overlays {
                if let connectionPolyline = overlay as? ConnectionPolyline {
                    let renderer = MKPolylineRenderer(polyline: connectionPolyline)
                    let polylinePoint = renderer.point(for: mapPoint)
                    
                    // Check if the click is near the connection line
                    let tolerance: CGFloat = 15.0
                    
                    if let path = renderer.path {
                        let boundingBox = path.boundingBox
                        let expandedBoundingBox = boundingBox.insetBy(dx: -tolerance, dy: -tolerance)
                        
                        if expandedBoundingBox.contains(polylinePoint) {
                            let distance = distanceFromPointToPath(polylinePoint, path: path)
                            if distance <= tolerance {
                                // Delete the connection
                                let connectionType = connectionPolyline.connectionType
                                let pointCount = connectionPolyline.pointCount
                                
                                if pointCount >= 2 {
                                    let points = connectionPolyline.points()
                                    let coordinates = UnsafeBufferPointer(start: points, count: pointCount).map {
                                        $0.coordinate
                                    }
                                    
                                    let fromCoord = coordinates[0]
                                    let toCoord = coordinates[1]
                                    
                                    parent.dataManager.deleteConnection(
                                        fromCoordinate: (fromCoord.latitude, fromCoord.longitude),
                                        toCoordinate: (toCoord.latitude, toCoord.longitude),
                                        connectionType: connectionType
                                    )
                                    return
                                }
                            }
                        }
                    }
                }
            }
            
            // If no connection was found, try to delete entire route (only of selected type)
            for overlay in mapView.overlays {
                if let polyline = overlay as? RoutePolyline,
                   isRouteOfSelectedType(polyline.routeName) {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    let polylinePoint = renderer.point(for: mapPoint)
                    
                    let tolerance: CGFloat = 15.0
                    
                    if let path = renderer.path {
                        let boundingBox = path.boundingBox
                        let expandedBox = boundingBox.insetBy(dx: -tolerance, dy: -tolerance)
                        
                        if expandedBox.contains(polylinePoint) {
                            // Found the road that was clicked
                            if let routeName = polyline.routeName {
                                let routeType = polyline.routeType
                                parent.dataManager.deleteRoute(routeName, type: routeType)
                                if parent.selectedRoute == routeName {
                                    parent.selectedRoute = nil
                                }
                                return
                            }
                        }
                    }
                }
            }
        }
        
        private func handleDeleteCity(at point: CGPoint, mapView: MKMapView) {
            // Check for city annotation selection
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coordinate)
            let rect = MKMapRect(x: mapPoint.x - 20, y: mapPoint.y - 20, width: 40, height: 40)
            let annotations = mapView.annotations(in: rect)
            
            for annotation in annotations {
                if let cityAnnotation = annotation as? CityAnnotation,
                   let city = cityAnnotation.city {
                    parent.dataManager.deleteCity(city)
                    if parent.selectedCity?.id == city.id {
                        parent.selectedCity = nil
                    }
                    return
                }
            }
        }
        

        
        // MARK: - MapView Delegate
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let routePolyline = overlay as? RoutePolyline {
                let renderer = MKPolylineRenderer(polyline: routePolyline)
                
                if routePolyline.isSelected {
                    renderer.strokeColor = NSColor.systemBlue
                    renderer.lineWidth = 5
                } else if routePolyline.isDeadEnd && parent.showingDeadEnds {
                    renderer.strokeColor = NSColor.systemOrange
                    renderer.lineWidth = 4
                } else {
                    // Set color based on road type
                    switch routePolyline.routeType {
                    case "interstate":
                        renderer.strokeColor = NSColor.systemGreen
                        renderer.lineWidth = 3
                    case "paved":
                        renderer.strokeColor = NSColor.systemBlue
                        renderer.lineWidth = 2
                    case "dirt":
                        renderer.strokeColor = NSColor.systemOrange
                        renderer.lineWidth = 2
                        renderer.lineDashPattern = [5, 5] // Dashed for dirt roads
                    default:
                    renderer.strokeColor = NSColor.systemGreen
                    renderer.lineWidth = 3
                    }
                }
                
                return renderer
            } else if let connectionPolyline = overlay as? ConnectionPolyline {
                let renderer = MKPolylineRenderer(polyline: connectionPolyline)
                
                switch connectionPolyline.connectionType {
                case "dirt":
                    renderer.strokeColor = NSColor.systemOrange.withAlphaComponent(0.5)
                    renderer.lineDashPattern = [5, 5]
                case "paved":
                    renderer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.5)
                default:
                    renderer.strokeColor = NSColor.systemGray.withAlphaComponent(0.5)
                }
                
                renderer.lineWidth = 2
                return renderer
            } else if let newRoadPolyline = overlay as? NewRoadPolyline {
                let renderer = MKPolylineRenderer(polyline: newRoadPolyline)
                renderer.strokeColor = NSColor.systemRed
                renderer.lineWidth = 4
                renderer.lineDashPattern = [10, 5]
                return renderer
            }
            
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cityAnnotation = annotation as? CityAnnotation {
                let identifier = "CityAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                }
                
                // Always update isDraggable when view is configured
                view?.isDraggable = parent.editMode == .moveCity
                
                view?.markerTintColor = cityAnnotation.city == parent.selectedCity ? .systemRed : .systemPurple
                view?.glyphImage = NSImage(systemSymbolName: "building.2", accessibilityDescription: nil)
                
                return view
            } else if let pointAnnotation = annotation as? RoutePointAnnotation {
                let identifier = "RoutePointAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                }
                
                // Always update isDraggable when view is configured, not just when created
                view?.isDraggable = parent.editMode == .movePoint
                
                let size: CGFloat = pointAnnotation.isSelected ? 12 : 8
                let color = pointAnnotation.isSelected ? NSColor.systemBlue : NSColor.systemGreen
                
                let image = NSImage(size: NSSize(width: size, height: size))
                image.lockFocus()
                color.setFill()
                NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()
                image.unlockFocus()
                
                view?.image = image
                view?.centerOffset = CGPoint(x: 0, y: -size/2)
                
                return view
            } else if annotation is NewRoadPointAnnotation {
                let identifier = "NewRoadPointAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                }
                
                let size: CGFloat = 10
                let color = NSColor.systemRed
                
                let image = NSImage(size: NSSize(width: size, height: size))
                image.lockFocus()
                color.setFill()
                NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()
                NSColor.white.setStroke()
                let strokePath = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: size-2, height: size-2))
                strokePath.lineWidth = 1
                strokePath.stroke()
                image.unlockFocus()
                
                view?.image = image
                view?.centerOffset = CGPoint(x: 0, y: -size/2)
                
                return view
            } else if let roadAnnotation = annotation as? RoadPointAnnotation {
                let identifier = "RoadPointAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                }
                
                // Always update isDraggable when view is configured
                view?.isDraggable = parent.editMode == .moveRoad
                
                let size: CGFloat = 10
                let color = roadAnnotation.isFromPoint ? NSColor.systemOrange : NSColor.systemRed
                
                let image = NSImage(size: NSSize(width: size, height: size))
                image.lockFocus()
                color.setFill()
                NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()
                NSColor.white.setStroke()
                let strokePath = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: size-2, height: size-2))
                strokePath.lineWidth = 2
                strokePath.stroke()
                image.unlockFocus()
                
                view?.image = image
                view?.centerOffset = CGPoint(x: 0, y: -size/2)
                
                return view
            } else if annotation is DeadEndPointAnnotation {
                let identifier = "DeadEndPointAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                }
                
                let size: CGFloat = 12
                let color = NSColor.systemRed
                
                let image = NSImage(size: NSSize(width: size, height: size))
                image.lockFocus()
                color.setFill()
                NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()
                NSColor.white.setStroke()
                let strokePath = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: size-2, height: size-2))
                strokePath.lineWidth = 2
                strokePath.stroke()
                image.unlockFocus()
                
                view?.image = image
                view?.centerOffset = CGPoint(x: 0, y: -size/2)
                
                return view
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let pointAnnotation = view.annotation as? RoutePointAnnotation {
                parent.selectedRoute = pointAnnotation.routeName
                parent.selectedPointIndex = pointAnnotation.pointIndex
                
                if parent.editMode == .deletePoint {
                    // Determine the road type for this route
                    let roadType: String
                    switch parent.selectedRoadType {
                    case .interstate:
                        roadType = "interstate"
                    case .paved:
                        roadType = "paved"
                    case .dirt:
                        roadType = "dirt"
                    }
                    
                    parent.dataManager.deletePoint(
                        from: pointAnnotation.routeName!,
                        at: pointAnnotation.pointIndex!,
                        roadType: roadType
                    )
                }
            } else if let cityAnnotation = view.annotation as? CityAnnotation,
                      let city = cityAnnotation.city {
                parent.selectedCity = city
                parent.selectedRoute = nil
                parent.selectedPointIndex = nil
                
                if parent.editMode == .deleteCity {
                    parent.dataManager.deleteCity(city)
                    parent.selectedCity = nil
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            if newState == .ending,
               let pointAnnotation = view.annotation as? RoutePointAnnotation,
               let route = pointAnnotation.routeName,
               let index = pointAnnotation.pointIndex {
                
                // Determine the road type for this route
                let roadType: String
                switch parent.selectedRoadType {
                case .interstate:
                    roadType = "interstate"
                case .paved:
                    roadType = "paved"
                case .dirt:
                    roadType = "dirt"
                }
                
                parent.dataManager.updatePoint(
                    in: route,
                    at: index,
                    to: (view.annotation!.coordinate.latitude, view.annotation!.coordinate.longitude),
                    roadType: roadType
                )
            } else if newState == .ending,
                      let cityAnnotation = view.annotation as? CityAnnotation,
                      let city = cityAnnotation.city {
                
                parent.dataManager.updateCity(
                    city,
                    name: city.name,
                    latitude: view.annotation!.coordinate.latitude,
                    longitude: view.annotation!.coordinate.longitude,
                    population: city.population
                )
            } else if newState == .ending,
                      let roadAnnotation = view.annotation as? RoadPointAnnotation,
                      let fromRoute = roadAnnotation.connectionFrom,
                      let toRoute = roadAnnotation.connectionTo,
                      let connectionType = roadAnnotation.connectionType {
                
                parent.dataManager.updateRoadPoint(
                    fromRoute: fromRoute,
                    toRoute: toRoute,
                    connectionType: connectionType,
                    isFromPoint: roadAnnotation.isFromPoint,
                    newCoordinate: (view.annotation!.coordinate.latitude, view.annotation!.coordinate.longitude)
                )
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Only update the binding if this is a user-initiated change
            // This prevents feedback loops when programmatically setting the region
            if isUserInteracting {
                DispatchQueue.main.async {
                    self.parent.mapRegion = mapView.region
                }
            }
            
            // Small delay to ensure the region change is complete before allowing programmatic updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isUserInteracting = false
            }
        }
        
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            isUserInteracting = true
        }
        
        // MARK: - Helper Functions
        
        private func distanceFromPointToPath(_ point: CGPoint, path: CGPath) -> CGFloat {
            // Simple distance calculation for path intersection
            let pathBounds = path.boundingBox
            let centerX = pathBounds.midX
            let centerY = pathBounds.midY
            let centerPoint = CGPoint(x: centerX, y: centerY)
            
            let distance = sqrt(pow(point.x - centerPoint.x, 2) + pow(point.y - centerPoint.y, 2))
            return distance
        }
        
        private func distanceFromPoint(_ point: (Double, Double), toLineSegment line: ((Double, Double), (Double, Double))) -> Double {
            let p = point
            let v = line.0
            let w = line.1
            
            let l2 = pow(v.0 - w.0, 2) + pow(v.1 - w.1, 2)
            if l2 == 0 { return sqrt(pow(p.0 - v.0, 2) + pow(p.1 - v.1, 2)) }
            
            let t = max(0, min(1, ((p.0 - v.0) * (w.0 - v.0) + (p.1 - v.1) * (w.1 - v.1)) / l2))
            let projection = (v.0 + t * (w.0 - v.0), v.1 + t * (w.1 - v.1))
            
            return sqrt(pow(p.0 - projection.0, 2) + pow(p.1 - projection.1, 2))
        }
    }
}

// MARK: - Custom Map Overlays

class RoutePolyline: MKPolyline {
    var routeName: String?
    var routeType: String = "interstate"
    var isSelected: Bool = false
    var isDeadEnd: Bool = false
}

class ConnectionPolyline: MKPolyline {
    var connectionType: String = "direct"
}

// MARK: - Custom Annotations

class RoutePointAnnotation: MKPointAnnotation {
    var routeName: String?
    var pointIndex: Int?
    var isSelected: Bool = false
}

class CityAnnotation: MKPointAnnotation {
    var city: MajorCity?
}

class NewRoadPolyline: MKPolyline {
    var isSelected: Bool = false
}

class NewRoadPointAnnotation: MKPointAnnotation {
    var pointIndex: Int?
}

class RoadPointAnnotation: MKPointAnnotation {
    var connectionFrom: String?
    var connectionTo: String?
    var connectionType: String?
    var isFromPoint: Bool = true
}

class DeadEndPointAnnotation: MKPointAnnotation {
    var routeName: String?
    var isEndpoint: Bool = true
}

 