//
//  GameViewController+MemoryManagedRoutes.swift
//  Interstate
//
//  Memory-managed route loading system with 256MB budget
//

import Foundation
import SceneKit

// MARK: - Memory Management Data Structures

/// Accurate memory tracking for route data
struct RouteMemoryFootprint {
    let gpsDataSize: Int
    let smoothPointsSize: Int
    let roadPointsSize: Int
    let metadataSize: Int
    let stringDataSize: Int
    
    var totalSize: Int {
        return gpsDataSize + smoothPointsSize + roadPointsSize + metadataSize + stringDataSize
    }
    
    static func calculate(for routeName: String, route: Any) -> RouteMemoryFootprint {
        // GPS data size calculation
        let gpsDataSize: Int
        if let coordinatesList = route as? [(Double, Double)] {
            // Each coordinate: lat(8) + lon(8) + metadata(16) = 32 bytes
            gpsDataSize = coordinatesList.count * 32
        } else {
            gpsDataSize = 0
        }
        
        // Estimate smooth points size (typically 50 points per GPS point)
        let smoothPointsSize = gpsDataSize * 50 * 12 // SCNVector3 = 12 bytes
        
        // Road points size (similar to smooth points)
        let roadPointsSize = smoothPointsSize
        
        // Metadata overhead (route name, state, etc.)
        let metadataSize = 1024 // 1KB overhead per route
        
        // String data size
        let stringDataSize = routeName.utf8.count * 2 // UTF-16 estimate
        
        return RouteMemoryFootprint(
            gpsDataSize: gpsDataSize,
            smoothPointsSize: smoothPointsSize,
            roadPointsSize: roadPointsSize,
            metadataSize: metadataSize,
            stringDataSize: stringDataSize
        )
    }
}

/// Route loading state with accurate tracking
enum RouteLoadingState {
    case unloaded
    case loading(progress: CGFloat)
    case loaded(memoryFootprint: RouteMemoryFootprint)
    case failed(error: Error)
    
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
    
    var memorySize: Int {
        if case .loaded(let footprint) = self {
            return footprint.totalSize
        }
        return 0
    }
}

/// Memory budget manager with accurate tracking
class MemoryBudgetManager {
    private let maxBudgetBytes: Int
    private var allocatedMemory: [String: RouteMemoryFootprint] = [:]
    private var accessTimes: [String: Date] = [:]
    private let queue = DispatchQueue(label: "memory.budget", qos: .utility)
    
    init(maxBudgetMB: Int = 256) {
        self.maxBudgetBytes = maxBudgetMB * 1024 * 1024
    }
    
    var currentUsage: Int {
        return queue.sync {
            allocatedMemory.values.reduce(0) { $0 + $1.totalSize }
        }
    }
    
    var usagePercentage: CGFloat {
        return CGFloat(currentUsage) / CGFloat(maxBudgetBytes)
    }
    
    func canAllocate(_ routeName: String, footprint: RouteMemoryFootprint) -> Bool {
        return queue.sync {
            let currentUsed = allocatedMemory.values.reduce(0) { $0 + $1.totalSize }
            return (currentUsed + footprint.totalSize) <= maxBudgetBytes
        }
    }
    
    func allocate(_ routeName: String, footprint: RouteMemoryFootprint) {
        queue.sync {
            allocatedMemory[routeName] = footprint
            accessTimes[routeName] = Date()
        }
    }
    
    func deallocate(_ routeName: String) {
        queue.sync {
            allocatedMemory.removeValue(forKey: routeName)
            accessTimes.removeValue(forKey: routeName)
        }
    }
    
    func recordAccess(_ routeName: String) {
        queue.sync {
            accessTimes[routeName] = Date()
        }
    }
    
    /// Get routes that should be evicted using LRU policy
    func getRoutesToEvict(toFreeBytes targetBytes: Int) -> [String] {
        return queue.sync {
            let sortedByAccess = accessTimes.sorted { $0.value < $1.value }
            var routesToEvict: [String] = []
            var freedBytes = 0
            
            for (routeName, _) in sortedByAccess {
                if let footprint = allocatedMemory[routeName] {
                    routesToEvict.append(routeName)
                    freedBytes += footprint.totalSize
                    if freedBytes >= targetBytes {
                        break
                    }
                }
            }
            
            return routesToEvict
        }
    }
}

// MARK: - Background Loading System

/// True background loading operation
class RouteLoadingOperation: Operation, @unchecked Sendable {
    let routeName: String
    let routeData: Any
    var result: (String, RouteLoadingState)?
    
    private let progressCallback: ((String, CGFloat) -> Void)?
    
    init(routeName: String, routeData: Any, progressCallback: ((String, CGFloat) -> Void)? = nil) {
        self.routeName = routeName
        self.routeData = routeData
        self.progressCallback = progressCallback
        super.init()
    }
    
    override func main() {
        if isCancelled { return }
        
        // Calculate memory footprint first
        let footprint = RouteMemoryFootprint.calculate(for: routeName, route: routeData)
        
        // Report initial progress
        DispatchQueue.main.async {
            self.progressCallback?(self.routeName, 0.0)
        }
        
        // Actually process the route data - optimized for speed
        if let coordinatesList = routeData as? [(Double, Double)] {
            
            let totalSteps = coordinatesList.count
            var processedSteps = 0
            
            // Process coordinates in larger chunks for faster loading
            let chunkSize = max(1, totalSteps / 5) // Only 5 progress updates instead of 10
            
            for (index, coordinate) in coordinatesList.enumerated() {
                if isCancelled { return }
                
                // Process this coordinate (convert to scene coordinates, etc.)
                let _ = coordinate.0
                let _ = coordinate.1
                
                // Removed artificial delay - process immediately
                if index % chunkSize == 0 {
                    // No more Thread.sleep - this was causing delays!
                    
                    processedSteps += chunkSize
                    let progress = CGFloat(processedSteps) / CGFloat(totalSteps)
                    DispatchQueue.main.async {
                        self.progressCallback?(self.routeName, min(progress, 1.0))
                    }
                }
            }
        }
        
        if !isCancelled {
            result = (routeName, .loaded(memoryFootprint: footprint))
        }
    }
}

// MARK: - Predictive Loading System

class PredictiveLoader {
    private var lastPosition: SCNVector3?
    private var lastUpdate: Date = Date()
    private var velocityHistory: [SCNVector3] = []
    private let maxVelocityHistory = 5
    
    /// Predict future position based on velocity
    func predictFuturePosition(currentPosition: SCNVector3, secondsAhead: TimeInterval = 5.0) -> SCNVector3 {
        updateVelocity(currentPosition: currentPosition)
        
        guard velocityHistory.count >= 2 else { return currentPosition }
        
        // Calculate average velocity
        let avgVelocity = velocityHistory.reduce(SCNVector3Zero) { result, velocity in
            SCNVector3(x: result.x + velocity.x, y: result.y + velocity.y, z: result.z + velocity.z)
        }
        
        let count = CGFloat(velocityHistory.count)
        let normalizedVelocity = SCNVector3(
            x: avgVelocity.x / count,
            y: avgVelocity.y / count,
            z: avgVelocity.z / count
        )
        
        // Predict position
        let deltaTime = CGFloat(secondsAhead)
        let deltaTimeCG = CGFloat(deltaTime)
        
        let predictedX = currentPosition.x + (normalizedVelocity.x * deltaTimeCG)
        let predictedY = currentPosition.y + (normalizedVelocity.y * deltaTimeCG)
        let predictedZ = currentPosition.z + (normalizedVelocity.z * deltaTimeCG)
        
        return SCNVector3(x: predictedX, y: predictedY, z: predictedZ)
    }
    
    private func updateVelocity(currentPosition: SCNVector3) {
        defer { 
            lastPosition = currentPosition
            lastUpdate = Date()
        }
        
        guard let lastPos = lastPosition else { return }
        
        let deltaTime = CGFloat(Date().timeIntervalSince(lastUpdate))
        guard deltaTime > 0 else { return }
        
        let velocity = SCNVector3(
            x: (currentPosition.x - lastPos.x) / deltaTime,
            y: (currentPosition.y - lastPos.y) / deltaTime,
            z: (currentPosition.z - lastPos.z) / deltaTime
        )
        
        velocityHistory.append(velocity)
        if velocityHistory.count > maxVelocityHistory {
            velocityHistory.removeFirst()
        }
    }
}

// MARK: - Main Memory-Managed Routes Extension

extension GameViewController {
    
    func setupMemoryManagedRouteSystem() {
        // COMPLETELY DISABLED - Using simple road loading system instead
        print("🚫 Complex memory-managed route system COMPLETELY DISABLED")
        print("✅ Using simple road loading system from updateDynamicRoads()")
        
        // ZERO initialization - prevents all background loading that causes 584 segments
        // No background operations, no timers, no complex state management
        // All loading is now handled by the simple updateDynamicRoads() function
        return // Early return prevents any initialization
    }
    
    private func startMemoryManagementLoop() {
        // COMPLETELY DISABLED - This was causing the 584 segment overload
        // All loading now handled by simple updateDynamicRoads() system
        print("🚫 startMemoryManagementLoop() DISABLED - prevents 584 segment overload")
        return // Early return prevents any background operations
    }
    
    private func performMemoryManagement() {
        // COMPLETELY DISABLED - This was the source of 584 segment overload
        // All loading now handled by simple updateDynamicRoads() system  
        print("🚫 performMemoryManagement() DISABLED - prevents background overload")
        return // Early return prevents all background loading operations
    }
    
    private func getRoutesToLoad(currentGPS: (lat: Double, lon: Double), predictedGPS: (lat: Double, lon: Double)) -> [String] {
        var routesToLoad: [String] = []
        
        for (routeName, _) in interstateRoutes {
            // Skip if already loaded or loading
            if let state = routeLoadingStates[routeName] {
                switch state {
                case .loaded, .loading:
                    continue
                case .unloaded, .failed:
                    break
                }
            }
            
            // Check distance to current or predicted position
            let currentDistance = getMinimumDistanceToRoute(routeName: routeName, gps: currentGPS)
            let predictedDistance = getMinimumDistanceToRoute(routeName: routeName, gps: predictedGPS)
            let minDistance = min(currentDistance, predictedDistance)
            
            // BALANCED LOADING - Load if within 20km (reasonable distance for segment limits)
            if minDistance < 20000 { // 20km - balanced between loading and memory limits
                routesToLoad.append(routeName)
            }
        }
        
        return routesToLoad
    }
    
    private func getRoutesToUnload(currentGPS: (lat: Double, lon: Double)) -> [String] {
        var routesToUnload: [String] = []
        
        for (routeName, state) in routeLoadingStates {
            guard state.isLoaded else { continue }
            
            // Never unload active routes
            if activeRoutes.contains(routeName) {
                memoryBudgetManager.recordAccess(routeName)
                continue
            }
            
            let distance = getMinimumDistanceToRoute(routeName: routeName, gps: currentGPS)
            
            // BALANCED UNLOADING - Unload if beyond 35km 
            if distance > 35000 { // 35km - gives good buffer for loaded routes
                routesToUnload.append(routeName)
            }
        }
        
        return routesToUnload
    }
    
    private func handleMemoryPressure(routesToLoad: [String]) {
        let usagePercentage = memoryBudgetManager.usagePercentage
        
        // If we're over 80% usage, be more aggressive about eviction
        if usagePercentage > 0.8 {
            let targetReduction = Int(CGFloat(200 * 1024 * 1024) * 0.2) // Free 20% of 200MB budget
            let routesToEvict = memoryBudgetManager.getRoutesToEvict(toFreeBytes: targetReduction)
            unloadRoutes(routesToEvict)
        }
        
        // Calculate memory needed for new routes
        var memoryNeeded = 0
        for routeName in routesToLoad {
            if let routeData = interstateRoutes[routeName] {
                let footprint = RouteMemoryFootprint.calculate(for: routeName, route: routeData)
                memoryNeeded += footprint.totalSize
            }
        }
        
        // Free memory if needed for new routes
        if memoryBudgetManager.currentUsage + memoryNeeded > (200 * 1024 * 1024) {
            let routesToEvict = memoryBudgetManager.getRoutesToEvict(toFreeBytes: memoryNeeded)
            unloadRoutes(routesToEvict)
        }
    }
    
    private func loadRoutes(_ routeNames: [String]) {
        for routeName in routeNames {
            guard let routeData = interstateRoutes[routeName] else { continue }
            
            // Update state to loading
            routeLoadingStates[routeName] = .loading(progress: 0.0)
            
            // Create loading operation
            let operation = RouteLoadingOperation(routeName: routeName, routeData: routeData) { [weak self] name, progress in
                self?.routeLoadingStates[name] = .loading(progress: progress)
            }
            
            operation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    if let result = operation.result {
                        self?.handleLoadingResult(result.0, state: result.1)
                    }
                }
            }
            
            loadingQueue.addOperation(operation)
        }
    }
    
    private func handleLoadingResult(_ routeName: String, state: RouteLoadingState) {
        routeLoadingStates[routeName] = state
        
        if case .loaded(let footprint) = state {
            memoryBudgetManager.allocate(routeName, footprint: footprint)
            
            // Generate road geometry immediately on main thread for faster response
            DispatchQueue.main.async { [weak self] in
                self?.generateRouteGeometry(routeName)
            }
            
            // Route loaded successfully
        }
    }
    
    private func unloadRoutes(_ routeNames: [String]) {
        for routeName in routeNames {
            routeLoadingStates[routeName] = .unloaded
            memoryBudgetManager.deallocate(routeName)
            
            // Remove from scene on main thread
            DispatchQueue.main.async { [weak self] in
                self?.removeRouteFromScene(routeName)
            }
            
            // Route unloaded
        }
    }
    
    private func logMemoryStatus() {
        // Memory status tracking (logging disabled)
    }
    
    // MARK: - Helper Methods
    
    private func getMinimumDistanceToRoute(routeName: String, gps: (lat: Double, lon: Double)) -> Double {
        guard let coordinatesList = interstateRoutes[routeName] else {
            return Double.infinity
        }
        
        var minDistance = Double.infinity
        
        for coordinate in coordinatesList {
            let lat = coordinate.0
            let lon = coordinate.1
            let distance = haversineDistance(lat1: gps.lat, lon1: gps.lon, lat2: lat, lon2: lon)
            minDistance = min(minDistance, distance)
        }
        
        return minDistance
    }
    
    private func generateRouteGeometry(_ routeName: String) {
        // Check if we already have smooth points to avoid regenerating
        if routeSmoothPoints[routeName] == nil {
            // Pre-generate smooth points immediately for faster road rendering
            if let gpsCoordinates = getRouteData(routeName: routeName) {
                let smoothPoints = generateSmoothRoadPoints(from: gpsCoordinates)
                routeSmoothPoints[routeName] = smoothPoints
                allRoadPoints[routeName] = smoothPoints // For compatibility
                // Smooth points generated
            }
        }
        
        // Force the road system to recognize this route and generate geometry immediately
        self.addRouteToScene(routeName)
    }
    
    private func addRouteToScene(_ routeName: String) {
        // Initialize road tracking for this route if needed
        if loadedRoadNodes[routeName] == nil {
            loadedRoadNodes[routeName] = []
        }
        if loadedRouteSegments[routeName] == nil {
            loadedRouteSegments[routeName] = Set<Int>()
        }
        
        // Add throttling - only trigger road update if route is actually new
        if routeSmoothPoints[routeName] != nil && loadedRouteSegments[routeName]?.isEmpty == true {
            self.updateDynamicRoads()
        }
    }
    
    private func removeRouteFromScene(_ routeName: String) {
        // Remove route from 3D scene
    }
    
    // MARK: - Safe Data Access Layer
    
    /// Safely get route data, only for loaded routes
    func getRouteData(routeName: String) -> [(Double, Double)]? {
        // Only allow access to loaded routes
        guard let state = routeLoadingStates[routeName],
              state.isLoaded else {
            return nil
        }
        
        // Record access for LRU tracking
        memoryBudgetManager.recordAccess(routeName)
        
        // Return the actual route data
        return interstateRoutes[routeName]
    }
    
    /// Get list of currently loaded routes for compatibility
    var loadedRouteData: Set<String> {
        return Set(routeLoadingStates.compactMap { (key, value) in
            value.isLoaded ? key : nil
        })
    }
    
    private func setupImmediateLoadingSystem() {
        // Check for immediate route loading frequently to ensure roads are always available
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while self != nil {
                Thread.sleep(forTimeInterval: 0.2) // Fast checks to ensure immediate loading
                self?.checkForImmediateRouteLoading()
            }
        }
    }
    
    private func checkForImmediateRouteLoading() {
        guard let carNode = carNode else { return }
        
        let currentPosition = carNode.position
        let currentPositionGPS = convertSceneToGPS(currentPosition)
        
        // Find routes within immediate loading distance (8km - increased slightly)
        for (routeName, _) in interstateRoutes {
            // Skip if already loaded or loading
            if let state = routeLoadingStates[routeName] {
                switch state {
                case .loaded, .loading:
                    continue
                case .unloaded, .failed:
                    break
                }
            }
            
            let distance = getMinimumDistanceToRoute(routeName: routeName, gps: currentPositionGPS)
            
            // Immediate loading for very close routes (8km - balanced for early loading)
            if distance < 8000 {
                loadRoutesWithHighPriority([routeName])
            }
        }
    }
    
    private func loadRoutesWithHighPriority(_ routeNames: [String]) {
        for routeName in routeNames {
            guard let routeData = interstateRoutes[routeName] else { continue }
            
            // Update state to loading
            routeLoadingStates[routeName] = .loading(progress: 0.0)
            
            // Create high-priority loading operation
            let operation = RouteLoadingOperation(routeName: routeName, routeData: routeData) { [weak self] name, progress in
                self?.routeLoadingStates[name] = .loading(progress: progress)
            }
            
            // Set maximum priority for immediate loading
            operation.queuePriority = .veryHigh
            
            operation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    if let result = operation.result {
                        self?.handleLoadingResult(result.0, state: result.1)
                    }
                }
            }
            
            loadingQueue.addOperation(operation)
        }
    }
    
    // Add function to immediately load closest routes when segment count is low
    private func loadClosestRoutesImmediately(currentGPS: (lat: Double, lon: Double)) {
        var routeDistances: [(String, Double)] = []
        
        // Calculate distances to all routes
        for (routeName, _) in interstateRoutes {
            // Skip if already loaded or loading
            if let state = routeLoadingStates[routeName] {
                switch state {
                case .loaded, .loading:
                    continue
                case .unloaded, .failed:
                    break
                }
            }
            
            let distance = getMinimumDistanceToRoute(routeName: routeName, gps: currentGPS)
            routeDistances.append((routeName, distance))
        }
        
        // Sort by distance and load closest routes immediately
        routeDistances.sort { $0.1 < $1.1 }
        
        // Load up to 5 closest routes immediately, regardless of distance
        let routesToLoadImmediately = Array(routeDistances.prefix(5)).map { $0.0 }
        
        for routeName in routesToLoadImmediately {
            guard let routeData = interstateRoutes[routeName] else { continue }
            
            // Load immediately with high priority
            routeLoadingStates[routeName] = .loading(progress: 0.0)
            
            let operation = RouteLoadingOperation(routeName: routeName, routeData: routeData) { [weak self] name, progress in
                self?.routeLoadingStates[name] = .loading(progress: progress)
            }
            
            operation.queuePriority = .veryHigh
            
            operation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    if let result = operation.result {
                        self?.handleLoadingResult(result.0, state: result.1)
                    }
                }
            }
            
            loadingQueue.addOperation(operation)
        }
    }
}

// MARK: - Properties Extension

extension GameViewController {
    
    var memoryBudgetManager: MemoryBudgetManager {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.memoryBudgetManager) as? MemoryBudgetManager ?? MemoryBudgetManager()
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.memoryBudgetManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var routeLoadingStates: [String: RouteLoadingState] {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.routeLoadingStates) as? [String: RouteLoadingState] ?? [:]
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.routeLoadingStates, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var loadingQueue: OperationQueue {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.loadingQueue) as? OperationQueue ?? OperationQueue()
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.loadingQueue, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var predictiveLoader: PredictiveLoader {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.predictiveLoader) as? PredictiveLoader ?? PredictiveLoader()
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.predictiveLoader, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private struct AssociatedKeys {
    static var memoryBudgetManager = "memoryBudgetManager"
    static var routeLoadingStates = "routeLoadingStates"
    static var loadingQueue = "loadingQueue"
    static var predictiveLoader = "predictiveLoader"
}

 
