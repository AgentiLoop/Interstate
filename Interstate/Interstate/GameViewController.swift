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

// MARK: - Player Path Tracking Structure

struct PathPoint {
    let position: SCNVector3
    let heading: Float
    let speed: Float
    let timestamp: TimeInterval
}

// MARK: - AI Car Structure

enum AICarPersonality {
    case chaser      // Yellow - Always pursues player directly (like Blinky)
    case interceptor // Green - Tries to get ahead of player (like Pinky)
    case racer       // Orange - Speeds past and stays ahead
    case wanderer    // Magenta - Sometimes follows, sometimes independent
}

struct AICar {
    let node: SCNNode
    var currentSpeed: Float
    var targetSpeed: Float
    var routeName: String
    var routePointIndex: Int
    var positionOnSegment: Float // 0.0 to 1.0 between two route points
    var lane: Int // -1 = left lane, 1 = right lane
    var color: NSColor
    var isSpinning: Bool = false
    var spinRotation: Float = 0.0
    var isGoingForward: Bool = true // Direction on the road
    var pathTargetIndex: Int = 0 // Index in player path to follow
    var steeringAngle: Float = 0.0 // Current steering angle for realistic turning
    var wheelBase: Float = 4.0 // Distance between axles for physics calculations
    var isFleeing: Bool = false // Whether car is fleeing after collision
    var fleeStartTime: TimeInterval = 0 // When fleeing started
    var personality: AICarPersonality // Unique behavior type
    var hasPassedPlayer: Bool = false // Track if this car has overtaken the player
}

class GameViewController: NSViewController {
    
    // MARK: - Scene and Camera Properties
    
    var sceneView: SCNView!
    var scene: SCNScene!
    var cameraNode: SCNNode!
    
    // MARK: - Car Properties
    
    var carNode: SCNNode!
    var carSpeed: Float = 0.0
    var maxSpeed: Float = 89.4  // m/s (~200 mph)
    var acceleration: Float = 10.0
    var deceleration: Float = 15.0
    var steeringAngle: Float = 0.0  // Current steering wheel angle
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
    var engineRPM: Float = 800.0  // Idle RPM
    var maxRPM: Float = 6500.0
    var isEngineRunning: Bool = false
    var lastSpeedForGearShift: Float = 0.0
    
    // Audio nodes for positional audio
    var engineAudioNode: SCNNode!
    var exhaustAudioNode: SCNNode!
    var tireAudioNodes: [SCNNode] = []
    
    // MARK: - Camera Properties
    
    var targetCameraPosition = SCNVector3(0, 0, 0)
    var targetCameraLookAt = SCNVector3(0, 0, 0)
    let cameraFollowSpeed: Float = 6.0 // Smooth following for high-speed driving
    let cameraHeight: Float = 8.0 // Good height for road visibility
    let cameraDistance: Float = 15.0 // Standard distance for good road visibility
    
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
    
    let maxSteeringAngle: Float = 35.0  // Realistic steering angle
    
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
    let intersectionRadius: Float = 30.0  // Radius of intersection zones
    
    // MARK: - GPS Conversion Properties
    
    let centerLatitude: Double = 39.8283  // Geographic center of USA (Kansas)
    let centerLongitude: Double = -98.5795
    let latitudeScale: Double = 111000.0  // meters per degree latitude
    let longitudeScale: Double = 87000.0   // meters per degree longitude at 39°N
    let sceneScale: Double = 0.01  // Scale down for SceneKit (1:100)
    
    // MARK: - Data Storage
    
    var interstateRoutes: [String: [(Double, Double)]] = [:]  // Will be loaded from JSON
    var majorCities: [(String, Double, Double, Int)] = []  // Will be loaded from JSON
    var highwayConnections: [String: [(String, Float, String)]] = [:]  // Precomputed highway connections
    
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
    
    // MARK: - AI Car Properties
    
    var aiCars: [AICar] = []
    let maxAICars = 4  // Exactly 4 ghost AI cars
    let aiCarSpawnDistance: Float = 300.0 // Spawn within 300m of player
    let aiCarDespawnDistance: Float = 1000.0 // Keep AI cars within 1km of player
    let aiCarColors: [NSColor] = [
        NSColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0),     // Bright yellow
        NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),     // Bright green
        NSColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),     // Bright orange
        NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)      // Magenta
    ]
    var masterCarModel: SCNNode? // Master car model for cloning
    
    // Player path tracking for ghost AI cars
    var playerPath: [PathPoint] = []
    var lastPathUpdateTime: TimeInterval = 0
    
    // Collision detection
    var isPlayerSpinning: Bool = false
    var playerSpinVelocity: Float = 0.0
    var playerSpinAngle: Float = 0.0
    let collisionDistance: Float = 5.0 // Collision detection radius
    
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
        setupDirtRoads()  // Add dirt roads to off-road cities
        setupHighwayConnections()  // Connect nearby highways
        setupAICars()  // Initialize AI cars
        setupControls()
        setupHUD()
        setupRadarMap()
        
        // Set the view to the scene
        sceneView.scene = scene
        sceneView.allowsCameraControl = false
        sceneView.showsStatistics = false
        sceneView.backgroundColor = NSColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0) // Sky blue
        
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
