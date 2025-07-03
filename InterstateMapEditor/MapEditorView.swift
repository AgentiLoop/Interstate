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
        // Update map region if significantly different
        if abs(mapView.region.center.latitude - mapRegion.center.latitude) > 1 ||
           abs(mapView.region.center.longitude - mapRegion.center.longitude) > 1 {
            mapView.setRegion(mapRegion, animated: true)
        }
        
        // Update overlays and annotations
        updateMapContent(mapView)
    }
    
    private func updateMapContent(_ mapView: MKMapView) {
        // Clear existing
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // Add route overlays
        for (routeName, routeCoords) in dataManager.interstateRoutes {
            let coordinates = routeCoords.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
            let polyline = RoutePolyline(coordinates: coordinates, count: coordinates.count)
            polyline.routeName = routeName
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
        
        // Add connection overlays
        if showingDirtRoads {
            for (fromRoute, connections) in dataManager.connections {
                for connection in connections {
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
                    }
                }
            }
        }
        
        // Add city annotations
        for city in dataManager.majorCities {
            let annotation = CityAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude)
            annotation.city = city
            annotation.title = city.name
            annotation.subtitle = "Pop: \(city.population)"
            mapView.addAnnotation(annotation)
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
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapEditorView
        
        init(_ parent: MapEditorView) {
            self.parent = parent
        }
        
        // MARK: - Map Interaction
        
        @objc func handleMapClick(_ gesture: NSClickGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let clickPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(clickPoint, toCoordinateFrom: mapView)
            
            switch parent.editMode {
            case .addPoint:
                handleAddPoint(coordinate: coordinate, mapView: mapView)
            case .addRoad:
                handleAddRoadPoint(coordinate: coordinate)
            case .addCity:
                handleAddCity(coordinate: coordinate)
            case .deleteRoad:
                handleDeleteRoad(at: clickPoint, mapView: mapView)
            case .select:
                handleSelection(at: clickPoint, mapView: mapView)
            default:
                break
            }
        }
        
        private func handleAddPoint(coordinate: CLLocationCoordinate2D, mapView: MKMapView) {
            guard let route = parent.selectedRoute else { return }
            
            // Find best insertion point
            if let routeCoords = parent.dataManager.interstateRoutes[route] {
                var bestIndex = 0
                var minDistance = Double.infinity
                
                for i in 0..<max(0, routeCoords.count - 1) {
                    let p1 = routeCoords[i]
                    let p2 = routeCoords[i + 1]
                    
                    // Calculate distance from click to line segment
                    let dist = distanceFromPoint(
                        (coordinate.latitude, coordinate.longitude),
                        toLineSegment: (p1, p2)
                    )
                    
                    if dist < minDistance {
                        minDistance = dist
                        bestIndex = i + 1
                    }
                }
                
                parent.dataManager.addPoint(
                    to: route,
                    at: bestIndex,
                    coordinate: (coordinate.latitude, coordinate.longitude)
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
                    parent.selectedRoute = pointAnnotation.routeName
                    parent.selectedPointIndex = pointAnnotation.pointIndex
                    parent.selectedCity = nil
                    return
                }
            }
            
            // Check for overlay selection
            
            for overlay in mapView.overlays {
                if let polyline = overlay as? RoutePolyline {
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
            // Check for overlay selection (roads)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coordinate)
            
            for overlay in mapView.overlays {
                if let polyline = overlay as? RoutePolyline {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    let polylinePoint = renderer.point(for: mapPoint)
                    
                    // Check if the click is near the polyline (within 10 points)
                    let tolerance: CGFloat = 15.0
                    let clickPoint = polylinePoint
                    
                    // Simple bounding box check first
                    if let path = renderer.path {
                        let boundingBox = path.boundingBox
                        let expandedBox = boundingBox.insetBy(dx: -tolerance, dy: -tolerance)
                        
                        if expandedBox.contains(clickPoint) {
                            // Found the road that was clicked
                            if let routeName = polyline.routeName {
                                // Trigger deletion confirmation through the closure
                                DispatchQueue.main.async {
                                    self.parent.onDeleteRoad(routeName)
                                }
                            }
                            return
                        }
                    }
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
                    renderer.strokeColor = NSColor.systemGreen
                    renderer.lineWidth = 3
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
                
                view?.markerTintColor = cityAnnotation.city == parent.selectedCity ? .systemRed : .systemPurple
                view?.glyphImage = NSImage(systemSymbolName: "building.2", accessibilityDescription: nil)
                
                return view
            } else if let pointAnnotation = annotation as? RoutePointAnnotation {
                let identifier = "RoutePointAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                    view?.isDraggable = parent.editMode == .movePoint
                }
                
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
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let pointAnnotation = view.annotation as? RoutePointAnnotation {
                parent.selectedRoute = pointAnnotation.routeName
                parent.selectedPointIndex = pointAnnotation.pointIndex
                
                if parent.editMode == .deletePoint {
                    parent.dataManager.deletePoint(
                        from: pointAnnotation.routeName!,
                        at: pointAnnotation.pointIndex!
                    )
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            if newState == .ending,
               let pointAnnotation = view.annotation as? RoutePointAnnotation,
               let route = pointAnnotation.routeName,
               let index = pointAnnotation.pointIndex {
                
                parent.dataManager.updatePoint(
                    in: route,
                    at: index,
                    to: (view.annotation!.coordinate.latitude, view.annotation!.coordinate.longitude)
                )
            }
        }
        
        func mapViewRegionDidChangeAnimated(_ mapView: MKMapView) {
            parent.mapRegion = mapView.region
        }
        
        // MARK: - Helper Functions
        
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

 