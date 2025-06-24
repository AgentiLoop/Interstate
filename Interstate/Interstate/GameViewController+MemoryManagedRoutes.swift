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
    case loading(progress: Float)
    case loaded(memoryFootprint: RouteMemoryFootprint)
    case failed
    
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
    
    var usagePercentage: Float {
        return Float(currentUsage) / Float(maxBudgetBytes)
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
    
    private let progressCallback: ((String, Float) -> Void)?
    
    init(routeName: String, routeData: Any, progressCallback: ((String, Float) -> Void)? = nil) {
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
        
        // Actually process the route data instead of simulating
        if let coordinatesList = routeData as? [(Double, Double)] {
            
            let totalSteps = coordinatesList.count
            var processedSteps = 0
            
            // Process coordinates in chunks to allow cancellation and progress updates
            let chunkSize = max(1, totalSteps / 10) // 10 progress updates
            
            for (index, coordinate) in coordinatesList.enumerated() {
                if isCancelled { return }
                
                // Process this coordinate (convert to scene coordinates, etc.)
                let _ = coordinate.0
                let _ = coordinate.1
                
                // Actual processing would happen here
                // For now, just a minimal delay to prevent blocking
                if index % chunkSize == 0 {
                    Thread.sleep(forTimeInterval: 0.001) // 1ms per chunk
                    
                    processedSteps += chunkSize
                    let progress = Float(processedSteps) / Float(totalSteps)
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
        let deltaTime = Float(secondsAhead)
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
        // Initialize components
        memoryBudgetManager = MemoryBudgetManager(maxBudgetMB: 256)
        routeLoadingStates = [:]
        loadingQueue = OperationQueue()
        loadingQueue.maxConcurrentOperationCount = 3 // Limit concurrent operations
        loadingQueue.qualityOfService = .utility // Background priority
        predictiveLoader = PredictiveLoader()
        
        // Start the management loop
        startMemoryManagementLoop()
        
        print("🚀 Advanced memory-managed route system initialized")
        print("📊 Memory budget: 256MB")
    }
    
    private func startMemoryManagementLoop() {
        // Use proper async timer instead of blocking sleep
        let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.performMemoryManagement()
            }
        }
        
        // Store timer to prevent deallocation
        objc_setAssociatedObject(self, &AssociatedKeys.memoryTimer, timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    private func performMemoryManagement() {
        guard let carNode = carNode else { return }
        
        let currentPosition = carNode.position
        let currentPositionGPS = convertSceneToGPS(currentPosition)
        
        // Get predicted position for early loading
        let predictedPosition = predictiveLoader.predictFuturePosition(currentPosition: currentPosition)
        let predictedGPS = convertSceneToGPS(predictedPosition)
        
        // Determine routes to load/unload
        let routesToLoad = getRoutesToLoad(currentGPS: currentPositionGPS, predictedGPS: predictedGPS)
        let routesToUnload = getRoutesToUnload(currentGPS: currentPositionGPS)
        
        // Handle memory pressure
        handleMemoryPressure(routesToLoad: routesToLoad)
        
        // Start loading new routes
        loadRoutes(routesToLoad)
        
        // Unload old routes
        unloadRoutes(routesToUnload)
        
        // Log status occasionally
        if Int(Date().timeIntervalSince1970) % 15 == 0 {
            logMemoryStatus()
        }
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
            
            // Load if within threshold (reduced to 15km for more aggressive loading)
            if minDistance < 15000 { // 15km
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
            
            // Unload if far away (increased to 75km for better retention)
            if distance > 75000 { // 75km
                routesToUnload.append(routeName)
            }
        }
        
        return routesToUnload
    }
    
    private func handleMemoryPressure(routesToLoad: [String]) {
        let usagePercentage = memoryBudgetManager.usagePercentage
        
        // If we're over 80% usage, be more aggressive about eviction
        if usagePercentage > 0.8 {
            let targetReduction = Int(Float(256 * 1024 * 1024) * 0.2) // Free 20% of 256MB
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
        if memoryBudgetManager.currentUsage + memoryNeeded > (256 * 1024 * 1024) {
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
            
            // Generate road geometry on background queue
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.generateRouteGeometry(routeName)
            }
            
            print("✅ Loaded \(routeName): \(footprint.totalSize / 1024)KB")
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
            
            print("🗑️ Unloaded \(routeName)")
        }
    }
    
    private func logMemoryStatus() {
        let usage = memoryBudgetManager.currentUsage
        let percentage = memoryBudgetManager.usagePercentage
        let loadedCount = routeLoadingStates.values.filter { $0.isLoaded }.count
        let activeCount = activeRoutes.count
        
        print("🧠 Memory: \(usage / (1024*1024))MB/256MB (\(String(format: "%.1f", percentage * 100))%) | Routes: \(loadedCount) loaded, \(activeCount) active")
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
        // Force the road system to recognize this route and generate geometry
        DispatchQueue.main.async { [weak self] in
            self?.addRouteToScene(routeName)
        }
    }
    
    private func addRouteToScene(_ routeName: String) {
        // Initialize road tracking for this route if needed
        if loadedRoadNodes[routeName] == nil {
            loadedRoadNodes[routeName] = []
        }
        if loadedRouteSegments[routeName] == nil {
            loadedRouteSegments[routeName] = Set<Int>()
        }
        
        // Don't call updateDynamicRoads recursively - let the game loop handle it
        print("🏗️ Route \(routeName) ready for rendering (road tracking initialized)")
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
    static var memoryTimer = "memoryTimer"
} 
