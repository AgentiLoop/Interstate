#!/usr/bin/env python3
"""
Fix all dead-end interstates by:
1. Connecting those within 10 miles to nearest road
2. Using dirt roads for interior dead ends not within 10 miles
3. Removing edge dead ends and adjusting endpoints
"""

import json
import math
from typing import Dict, List, Tuple, Optional
import copy

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points in miles using Haversine formula."""
    R = 3959  # Radius of Earth in miles
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)
    
    a = math.sin(delta_lat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def find_map_boundaries(routes: Dict) -> Tuple[float, float, float, float]:
    """Find the boundaries of the map (min/max lat/lon)."""
    min_lat = float('inf')
    max_lat = float('-inf')
    min_lon = float('inf')
    max_lon = float('-inf')
    
    for route_name, coords in routes.items():
        for lat, lon in coords:
            min_lat = min(min_lat, lat)
            max_lat = max(max_lat, lat)
            min_lon = min(min_lon, lon)
            max_lon = max(max_lon, lon)
    
    return min_lat, max_lat, min_lon, max_lon

def is_edge_point(lat: float, lon: float, boundaries: Tuple[float, float, float, float], threshold: float = 50) -> bool:
    """Check if a point is near the edge of the map."""
    min_lat, max_lat, min_lon, max_lon = boundaries
    
    # Calculate distances to each edge in miles
    north_dist = calculate_distance(lat, lon, max_lat, lon)
    south_dist = calculate_distance(lat, lon, min_lat, lon)
    east_dist = calculate_distance(lat, lon, lat, max_lon)
    west_dist = calculate_distance(lat, lon, lat, min_lon)
    
    # Check if within threshold miles of any edge
    return any(dist < threshold for dist in [north_dist, south_dist, east_dist, west_dist])

def find_nearest_route_point(lat: float, lon: float, routes: Dict, exclude_route: str = None) -> Tuple[str, int, float]:
    """Find the nearest point on any route to the given location."""
    min_distance = float('inf')
    nearest_route = None
    nearest_index = -1
    
    for route_name, coords in routes.items():
        if route_name == exclude_route:
            continue
            
        for i, (r_lat, r_lon) in enumerate(coords):
            dist = calculate_distance(lat, lon, r_lat, r_lon)
            if dist < min_distance:
                min_distance = dist
                nearest_route = route_name
                nearest_index = i
    
    return nearest_route, nearest_index, min_distance

def find_connected_routes(connections: Dict) -> set:
    """Find all routes that have at least one connection."""
    connected = set()
    for from_route, conns in connections.items():
        connected.add(from_route)
        for conn in conns:
            connected.add(conn['to'])
    return connected

def main():
    # Load current data
    with open('interstate_routes_with_connections.json', 'r') as f:
        data = json.load(f)
    
    routes = data['interstateRoutes']
    connections = data.get('connections', {})
    
    # Find boundaries
    boundaries = find_map_boundaries(routes)
    print(f"Map boundaries: Lat {boundaries[0]:.2f} to {boundaries[1]:.2f}, Lon {boundaries[2]:.2f} to {boundaries[3]:.2f}")
    
    # Find dead ends
    connected_routes = find_connected_routes(connections)
    all_routes = set(routes.keys())
    dead_ends = all_routes - connected_routes
    
    print(f"\nFound {len(dead_ends)} dead-end routes")
    
    # Create a copy for modifications
    new_data = copy.deepcopy(data)
    removed_routes = []
    
    # Process each dead end
    for route in sorted(dead_ends):
        coords = routes[route]
        if not coords:
            continue
            
        print(f"\nProcessing {route}:")
        
        # Check both endpoints
        start_lat, start_lon = coords[0]
        end_lat, end_lon = coords[-1]
        
        # Find nearest routes to both ends
        start_nearest, start_idx, start_dist = find_nearest_route_point(start_lat, start_lon, routes, route)
        end_nearest, end_idx, end_dist = find_nearest_route_point(end_lat, end_lon, routes, route)
        
        # Determine if endpoints are on edge
        start_on_edge = is_edge_point(start_lat, start_lon, boundaries)
        end_on_edge = is_edge_point(end_lat, end_lon, boundaries)
        
        print(f"  Start: ({start_lat:.2f}, {start_lon:.2f}) - Nearest: {start_nearest} at {start_dist:.1f} miles - Edge: {start_on_edge}")
        print(f"  End: ({end_lat:.2f}, {end_lon:.2f}) - Nearest: {end_nearest} at {end_dist:.1f} miles - Edge: {end_on_edge}")
        
        # Rule 3: If both endpoints are on edge, remove the route
        if start_on_edge and end_on_edge:
            print(f"  → Removing {route} (both endpoints on map edge)")
            del new_data['interstateRoutes'][route]
            removed_routes.append(route)
            continue
        
        # Check which end needs connection
        connections_to_add = []
        
        if start_dist < end_dist:
            # Connect start point
            if start_dist <= 10:
                # Rule 1: Direct connection if within 10 miles
                connection_type = "paved"
                print(f"  → Connecting start to {start_nearest} (direct paved, {start_dist:.1f} miles)")
            else:
                # Rule 2: Dirt road for interior connections
                connection_type = "dirt"
                print(f"  → Connecting start to {start_nearest} (dirt road, {start_dist:.1f} miles)")
            
            connections_to_add.append({
                'from': route,
                'to': start_nearest,
                'distance': start_dist,
                'type': connection_type
            })
        else:
            # Connect end point
            if end_dist <= 10:
                connection_type = "paved"
                print(f"  → Connecting end to {end_nearest} (direct paved, {end_dist:.1f} miles)")
            else:
                connection_type = "dirt"
                print(f"  → Connecting end to {end_nearest} (dirt road, {end_dist:.1f} miles)")
            
            connections_to_add.append({
                'from': route,
                'to': end_nearest,
                'distance': end_dist,
                'type': connection_type
            })
        
        # Add connections
        for conn in connections_to_add:
            if conn['from'] not in new_data['connections']:
                new_data['connections'][conn['from']] = []
            
            # Add connection in both directions
            new_data['connections'][conn['from']].append({
                'to': conn['to'],
                'distance': conn['distance'],
                'type': conn['type']
            })
            
            # Add reverse connection
            if conn['to'] not in new_data['connections']:
                new_data['connections'][conn['to']] = []
            
            new_data['connections'][conn['to']].append({
                'to': conn['from'],
                'distance': conn['distance'],
                'type': conn['type']
            })
    
    # Verify no dead ends remain
    final_connected = find_connected_routes(new_data['connections'])
    final_all_routes = set(new_data['interstateRoutes'].keys())
    final_dead_ends = final_all_routes - final_connected
    
    print(f"\n=== SUMMARY ===")
    print(f"Routes removed: {len(removed_routes)} - {removed_routes}")
    print(f"Remaining routes: {len(final_all_routes)}")
    print(f"Remaining dead ends: {len(final_dead_ends)} - {sorted(final_dead_ends) if final_dead_ends else 'None!'}")
    
    # Save the updated data
    with open('interstate_routes_no_dead_ends.json', 'w') as f:
        json.dump(new_data, f, indent=2)
    
    print(f"\nSaved updated data to interstate_routes_no_dead_ends.json")

if __name__ == "__main__":
    main() 