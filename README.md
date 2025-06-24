# Interstate Highway Driving Game

An immersive 3D driving game built with SceneKit that lets you drive on a network of major US interstate highways.

## Features

### 🛣️ Highway System
- **Major Interstate Routes**: Drive on simplified versions of I-95, I-10, I-40, I-80, and I-75
- **Realistic Road Markings**: Yellow center lines and white lane markers
- **Interstate Signs**: Green highway signs at major intersections
- **Lane-based Driving**: Multi-lane highways with proper markings

### 🚗 Vehicle Physics
- **Realistic Car Model**: 3D car with body, roof, and wheels
- **Smooth Controls**: WASD keyboard controls for acceleration, braking, and steering
- **Physics-based Movement**: Realistic acceleration, deceleration, and steering response
- **Speed Limiter**: Maximum speed limits for safe driving

### 🌍 Environment
- **Scenic Landscape**: Green grass terrain with blue sky
- **Random Trees**: Procedurally placed trees away from roadways
- **Traffic Cars**: Static traffic vehicles on highways for realism
- **Clouds**: Atmospheric cloud formations
- **Dynamic Lighting**: Sun and ambient lighting with shadows

### 📱 HUD Interface
- **Speedometer**: Real-time speed display in MPH
- **Route Indicator**: Shows current interstate highway
- **Control Instructions**: On-screen driving controls guide
- **Statistics**: Performance metrics display

## Controls

| Key | Action |
|-----|--------|
| **W** | Accelerate forward |
| **S** | Brake / Reverse |
| **A** | Steer left |
| **D** | Steer right |

## How to Play

1. **Launch the Game**: Run the Interstate app
2. **Start Driving**: Use W to accelerate and begin moving
3. **Navigate**: Use A/D to steer left and right
4. **Explore**: Drive between different interstate highways
5. **Monitor Speed**: Keep an eye on the speedometer in the top-right
6. **Follow Routes**: Watch the route indicator to see which interstate you're on

## Interstate Routes

The game includes simplified versions of major US interstates:

- **I-95**: East Coast corridor (North-South)
- **I-10**: Southern transcontinental route (East-West)
- **I-40**: Central transcontinental route (East-West)  
- **I-80**: Northern transcontinental route (East-West)
- **I-75**: Eastern corridor (North-South)

## Technical Details

- **Engine**: SceneKit (macOS native 3D framework)
- **Platform**: macOS
- **Language**: Swift
- **Camera**: Third-person follow camera
- **Physics**: Custom vehicle dynamics
- **Rendering**: Real-time 3D with shadows and lighting

## Future Enhancements

- [ ] More detailed interstate network
- [ ] Moving traffic with AI
- [ ] Weather effects (rain, fog)
- [ ] Day/night cycle
- [ ] Multiple vehicle types
- [ ] Sound effects and music
- [ ] Collision detection
- [ ] GPS-style navigation
- [ ] Real GIS data integration

## Based on Real Data

This game is inspired by real US interstate highway data from:
- **TIGER/Line Shapefiles** (US Census Bureau)
- **National Highway Planning Network** (FHWA)
- **Highway Performance Monitoring System** (HPMS)

The actual interstate system spans over 450,000 miles across the United States. This game provides a simplified but representative driving experience on America's highway network.

---

*Drive safely and explore the interstate system!* 🚗💨 