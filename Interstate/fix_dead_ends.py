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

def find_connected_endpoints(connections: Dict, routes: Dict) -> set:
    """Find all endpoints that have connections."""
    connected_endpoints = set()
    
    for from_route, conns in connections.items():
        if from_route in routes:
            for conn in conns:
                if conn['to'] in routes:
                    # Mark both endpoints as potentially connected
                    # We'll need to check specific connection points
                    if 'fromPoint' in conn and 'toPoint' in conn:
                        # Specific connection points are defined
                        from_coords = routes[from_route]
                        to_coords = routes[conn['to']]
                        
                        if from_coords and to_coords:
                            from_start = from_coords[0]
                            from_end = from_coords[-1]
                            
                            from_point = tuple(conn['fromPoint'])
                            to_point = tuple(conn['toPoint'])
                            
                            # Check which endpoint matches the connection
                            start_dist = calculate_distance(from_start[0], from_start[1], from_point[0], from_point[1])
                            end_dist = calculate_distance(from_end[0], from_end[1], from_point[0], from_point[1])
                            
                            if start_dist < 1:  # Within 1 mile
                                connected_endpoints.add(f"{from_route}-start")
                            if end_dist < 1:  # Within 1 mile
                                connected_endpoints.add(f"{from_route}-end")
                            
                            # Check the 'to' route endpoint
                            to_start = to_coords[0]
                            to_end = to_coords[-1]
                            
                            to_start_dist = calculate_distance(to_start[0], to_start[1], to_point[0], to_point[1])
                            to_end_dist = calculate_distance(to_end[0], to_end[1], to_point[0], to_point[1])
                            
                            if to_start_dist < 1:  # Within 1 mile
                                connected_endpoints.add(f"{conn['to']}-start")
                            if to_end_dist < 1:  # Within 1 mile
                                connected_endpoints.add(f"{conn['to']}-end")
    
    return connected_endpoints

def main():
    # Load current data
    with open('interstate_routes_with_connections.json', 'r') as f:
        data = json.load(f)
    
    routes = data['interstateRoutes']
    connections = data.get('connections', {})
    
    # Find boundaries
    boundaries = find_map_boundaries(routes)
    print(f"Map boundaries: Lat {boundaries[0]:.2f} to {boundaries[1]:.2f}, Lon {boundaries[2]:.2f} to {boundaries[3]:.2f}")
    
    # Find dead end endpoints
    connected_endpoints = find_connected_endpoints(connections, routes)
    all_endpoints = set()
    
    # Create all possible endpoints
    for route_name in routes.keys():
        all_endpoints.add(f"{route_name}-start")
        all_endpoints.add(f"{route_name}-end")
    
    dead_end_endpoints = all_endpoints - connected_endpoints
    
    print(f"\nFound {len(dead_end_endpoints)} dead-end endpoints")
    for endpoint in sorted(dead_end_endpoints):
        print(f"  {endpoint}")
    
    # Create a copy for modifications
    new_data = copy.deepcopy(data)
    removed_routes = []
    
    # Process each dead end endpoint
    for endpoint in sorted(dead_end_endpoints):
        # Parse endpoint (e.g., "I-90-start" or "I-70-end")
        parts = endpoint.rsplit('-', 1)
        if len(parts) != 2:
            continue
            
        route_name, endpoint_type = parts
        if route_name not in routes:
            continue
            
        coords = routes[route_name]
        if not coords:
            continue
            
        print(f"\nProcessing {endpoint}:")
        
        # Get the specific endpoint coordinate
        if endpoint_type == "start":
            endpoint_lat, endpoint_lon = coords[0]
        else:  # "end"
            endpoint_lat, endpoint_lon = coords[-1]
        
        # Find nearest route point
        nearest_route, nearest_idx, nearest_dist = find_nearest_route_point(endpoint_lat, endpoint_lon, routes, route_name)
        
        # Determine if endpoint is on edge
        on_edge = is_edge_point(endpoint_lat, endpoint_lon, boundaries)
        
        print(f"  Coordinate: ({endpoint_lat:.2f}, {endpoint_lon:.2f})")
        print(f"  Nearest: {nearest_route} at {nearest_dist:.1f} miles")
        print(f"  On edge: {on_edge}")
        
        # Rule 3: If endpoint is on edge, remove the route entirely
        if on_edge:
            print(f"  → Removing {route_name} (endpoint on map edge)")
            if route_name in new_data['interstateRoutes']:
                del new_data['interstateRoutes'][route_name]
                removed_routes.append(route_name)
            continue
        
        # Add connection for this endpoint
        if nearest_dist <= 10:
            # Rule 1: Direct connection if within 10 miles
            connection_type = "paved"
            print(f"  → Connecting {endpoint} to {nearest_route} (direct paved, {nearest_dist:.1f} miles)")
        else:
            # Rule 2: Dirt road for interior connections
            connection_type = "dirt"
            print(f"  → Connecting {endpoint} to {nearest_route} (dirt road, {nearest_dist:.1f} miles)")
        
        # Add connection
        if route_name not in new_data['connections']:
            new_data['connections'][route_name] = []
        
        # Add connection in both directions
        new_data['connections'][route_name].append({
            'to': nearest_route,
            'distance': nearest_dist,
            'type': connection_type
        })
        
        # Add reverse connection
        if nearest_route not in new_data['connections']:
            new_data['connections'][nearest_route] = []
        
        new_data['connections'][nearest_route].append({
            'to': route_name,
            'distance': nearest_dist,
            'type': connection_type
        })
    
    # Verify no dead end endpoints remain
    final_connected_endpoints = find_connected_endpoints(new_data['connections'], new_data['interstateRoutes'])
    final_all_endpoints = set()
    
    # Create all possible endpoints for remaining routes
    for route_name in new_data['interstateRoutes'].keys():
        final_all_endpoints.add(f"{route_name}-start")
        final_all_endpoints.add(f"{route_name}-end")
    
    final_dead_end_endpoints = final_all_endpoints - final_connected_endpoints
    
    print(f"\n=== SUMMARY ===")
    print(f"Routes removed: {len(removed_routes)} - {removed_routes}")
    print(f"Remaining routes: {len(new_data['interstateRoutes'])}")
    print(f"Remaining dead end endpoints: {len(final_dead_end_endpoints)}")
    if final_dead_end_endpoints:
        for endpoint in sorted(final_dead_end_endpoints):
            print(f"  {endpoint}")
    else:
        print("  None! All endpoints are now connected.")
    
    # Save the updated data
    with open('interstate_routes_no_dead_ends.json', 'w') as f:
        json.dump(new_data, f, indent=2)
    
    print(f"\nSaved updated data to interstate_routes_no_dead_ends.json")

if __name__ == "__main__":
    main() 