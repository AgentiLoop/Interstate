//
//  GameViewController.swift
//  Interstate
//
//  Created by Todd Bruss on 6/19/25.
//

import SceneKit
import QuartzCore
import AVFoundation
import Darwin

class GameViewController: NSViewController {
    
    // MARK: - Scene and Camera Properties
    
    var sceneView: SCNView!
    var scene: SCNScene!
    var cameraNode: SCNNode!
    
    // MARK: - Car Properties
    
    var carNode: SCNNode!
    var carSpeed: CGFloat = 0.0
    var maxSpeed: CGFloat = 89.4  // m/s (~200 mph)
    var acceleration: CGFloat = 10.0
    var deceleration: CGFloat = 15.0
    var steeringAngle: CGFloat = 0.0  // Current steering wheel angle
    var isAccelerating = false
    var isBraking = false
    var isTurningLeft = false
    var isTurningRight = false
    
    // MARK: - Car Audio System Properties
    
    // Audio sources
    var engineStartSound: SCNAudioSource!
    var engineIdleSound: SCNAudioSource!
    var engineRevSound: SCNAudioSource!
    var engineShiftingSounds: [SCNAudioSource] = []
    var tireSquealSound: SCNAudioSource!
    var brakeSound: SCNAudioSource!
    
    // Audio players for continuous sounds
    var engineIdlePlayer: SCNAudioPlayer?
    var engineRevPlayer: SCNAudioPlayer?
    var tireSquealPlayer: SCNAudioPlayer?
    
    // Audio state tracking
    var currentGear: Int = 1
    var engineRPM: CGFloat = 800.0  // Idle RPM
    var maxRPM: CGFloat = 6500.0
    var isEngineRunning: Bool = false
    var lastSpeedForGearShift: CGFloat = 0.0
    
    // Audio nodes for positional audio
    var engineAudioNode: SCNNode!
    var exhaustAudioNode: SCNNode!
    var tireAudioNodes: [SCNNode] = []
    
    // MARK: - Camera Properties
    
    var targetCameraPosition = SCNVector3(0, 0, 0)
    var targetCameraLookAt = SCNVector3(0, 0, 0)
    let cameraFollowSpeed: CGFloat = 6.0 // Smooth following for high-speed driving
    let cameraHeight: CGFloat = 8.0 // Good height for road visibility
    let cameraDistance: CGFloat = 15.0 // Standard distance for good road visibility
    
    // MARK: - HUD Properties
    
    var hudContainer: NSView!
    var speedLabel: NSTextField!
    var currentRouteLabel: NSTextField!
    var instructionsLabel: NSTextField!
    var compassLabel: NSTextField!
    var segmentCountLabel: NSTextField! // For simple road loading system
    
    // MARK: - Radar Map Properties
    
    var radarContainer: NSView!
    var radarMapView: NSView!
    var carTrail: [CGPoint] = []
    let radarScale: CGFloat = 0.0035  // Scale factor for radar map - LARGER for better visibility
    var radarCarLayer: CAShapeLayer!
    
    // MARK: - Steering Properties
    
    let maxSteeringAngle: CGFloat = 35.0  // Realistic steering angle
    
    // MARK: - Game Timer
    
    var gameTimer: Timer?
    
    // MARK: - Position Saving
    
    var lastSavedPosition: (Double, Double) = (34.0522, -118.2437) // Default to LA
    
    // MARK: - Checkpoint and Scoring System
    
    var currentScore: Int = 0
    var highScore: Int = 0
    var totalDrivingTime: TimeInterval = 0
    var lastCheckpointTime: TimeInterval = 0
    var gameStartTime: Date?
    var checkpointsReached: Set<String> = []
    var scoreLabel: NSTextField!
    var timeLabel: NSTextField!
    
    // MARK: - Road System Properties
    
    var allRoadPoints: [String: [(CGFloat, CGFloat)]] = [:]
    var intersectionZones: [SCNVector3] = []
    let intersectionRadius: CGFloat = 30.0  // Radius of intersection zones
    
    // MARK: - GPS Conversion Properties
    
    let centerLatitude: Double = 39.8283  // Geographic center of USA (Kansas)
    let centerLongitude: Double = -98.5795
    let latitudeScale: Double = 111000.0  // meters per degree latitude
    let longitudeScale: Double = 87000.0   // meters per degree longitude at 39°N
    let sceneScale: Double = 0.01  // Scale down for SceneKit (1:100)
    
    // MARK: - Data Storage
    
    var interstateRoutes: [String: [(Double, Double)]] = [:]  // Interstate highways (green, on radar)
    var pavedRoutes: [String: [(Double, Double)]] = [:]      // Paved roads (light gray, no radar)
    var dirtRoutes: [String: [(Double, Double)]] = [:]       // Dirt roads (orange, no radar)
    var majorCities: [(String, Double, Double, Int)] = []     // Will be loaded from JSON
    var highwayConnections: [String: [(String, CGFloat, String)]] = [:]  // Precomputed highway connections
    
    // MARK: - Audio Update Properties
    
    var lastAudioUpdateTime: TimeInterval = 0
    var audioUpdateInterval: TimeInterval = 1.0 // Update audio once per second (1/60th of 60fps)
    var lastEngineRPM: Double = 0
    var lastGear: Int = 1
    
    // MARK: - Simple Road Loading Properties
    
    // The new simple road loading system in GameViewController+RoadSystem.swift
    // handles all road loading with these data structures:
    var loadedRoadSegments: [String: SCNNode] = [:] // Simple segment tracking: key -> node
    var roadSystemNode: SCNNode = SCNNode() // Root node for all road segments
    
    // Store route data efficiently
    var routeGPSData: [String: [(Double, Double)]] = [:]
    
    // Legacy properties (kept for compatibility but not used by simple system)
    var loadedRoadNodes: [String: [SCNNode]] = [:] // Not used by simple system
    var loadedRouteSegments: [String: Set<Int>] = [:] // Not used by simple system
    let roadLoadDistance: CGFloat = 800.0 // Not used - simple system has own constants
    let roadUnloadDistance: CGFloat = 1200.0 // Not used - simple system has own constants
    var lastRoadUpdatePosition: SCNVector3 = SCNVector3(0, 0, 0) // Not used
    var roadUpdateThreshold: CGFloat = 150.0 // Not used - simple system doesn't throttle
    var routeSmoothPoints: [String: [(CGFloat, CGFloat)]] = [:] // Not used by simple system
    var lastRouteProcessTime: [String: Date] = [:] // Not used by simple system
    let routeProcessThrottleInterval: TimeInterval = 5.0 // Not used by simple system
    // OLD SYSTEM VARIABLES - COMPLETELY DISABLED to prevent 584 segment overload
    let maxTotalSegments: Int = 200 // OBSOLETE - simple system uses MAX_SEGMENTS = 350
    var currentTotalSegments: Int = 0 // OBSOLETE - simple system uses loadedRoadSegments.count
    
    // SIMPLE ROAD LOADING SYSTEM VARIABLES
    var roadUpdateCounter = 0 // Reduces loading frequency to prevent stalls
    var lastWorldOriginRebase: SCNVector3 = SCNVector3Zero // For floating point precision fix
    
    // MARK: - Dynamic Checkpoint Loading Properties
    
    var loadedCheckpoints: [String: SCNNode] = [:] // Track loaded checkpoint nodes
    let checkpointLoadDistance: CGFloat = 3000.0 // Load checkpoints within 3km
    let checkpointUnloadDistance: CGFloat = 4000.0 // Unload checkpoints beyond 4km
    var checkpointPositions: [String: (SCNVector3, Int)] = [:] // Cache checkpoint positions and populations
    
    // MARK: - Memory Management
    
    var lastMemoryCleanup: Date = Date()
    let memoryCleanupInterval: TimeInterval = 30.0 // Clean every 30 seconds (much less aggressive)
    
    // MARK: - Active Routes Tracking (for the new memory system)
    
    // Track currently active routes (being driven on)
    var activeRoutes: Set<String> = Set()
    var lastActiveRouteCheck: Date = Date()
    
    // Debug
    var frameCount: Int = 0
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load data from JSON files first
        loadInterstateRoutesFromJSON()
        loadMajorCitiesFromJSON()
        
        // Setup SceneKit view
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.width, .height]
        view.addSubview(sceneView)
        
        // Setup the scene
        setupScene()
        setupCar()
        setupCamera()
        // setupRoads() - Removed: Simple road loading system loads roads dynamically in updateDynamicRoads()
        setupCheckpointGates()  // Initialize checkpoint positions
        // setupDirtRoads()  // DISABLED: All roads must come from map data
        // setupHighwayConnections()  // DISABLED: All road connections must come from map data
        setupControls()
        setupHUD()
        setupRadarMap()
        
        // Set the view to the scene
        sceneView.scene = scene
        sceneView.allowsCameraControl = false
        sceneView.showsStatistics = false
        sceneView.backgroundColor = NSColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0) // Sky blue
        sceneView.antialiasingMode = .multisampling4X
        
        // Force clear color to ensure ground shows
        scene.background.contents = NSColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0)
        
        // Start the game loop
        _ = Timer.scheduledTimer(timeInterval: 1.0/60.0, target: self, selector: #selector(gameLoop), userInfo: nil, repeats: true)
    }
    
    deinit {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
        print("🧹 GameViewController deinitialized and observers removed")
    }
}
