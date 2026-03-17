extends Node
class_name CirclePackedPolygon

# File: drawn_polygon.gd

@export var cell_size = 256.0

var polygon: = PackedVector2Array([]):
	set(value):
		polygon = value
		clockwise = Geometry2D.is_polygon_clockwise(polygon)
var circle_grid: Dictionary[Vector2i, Array] = {}
var edge_grid: Dictionary[Vector2i, Array]= {}
var circles: Array[Circle] = []

var clockwise: bool = false


var origin = Vector2.ZERO:
	get():
		return polygon[0] if polygon.size() != 0 else Vector2.ZERO

func _init(_polygon: PackedVector2Array):
	self.polygon = _polygon
	generate_grid()

func generate_grid():
	# The polygon isn't valid, so exit
	if polygon.size() < 2: return
	
	edge_grid.clear()
	for idx in polygon.size():
		var next_idx = wrapi(idx+1, 0, polygon.size())
		var edge: Edge = Edge.new(
			polygon[idx],
			polygon[next_idx]
		)
		
		# Place on edges into a grid for quicker accessing
		for coordinate in edge.get_coordinates(cell_size, origin):
			edge_grid.get_or_add(coordinate, []).push_back(edge)

# A circle-polygon intersection method
func circle_intersects_polygon(circle: Circle, threshold=1):
	var intersections: int = 0
	var visited: Dictionary[Edge, bool] = {}
	for coordinate in circle.get_coordinates(cell_size, origin):
		var edges: Array = edge_grid.get(coordinate, [])
		for edge in edges:
			if visited.has(edge):
				continue
			visited.set(edge, true)
			if circle_intersects_edge(edge, circle) != -1:
				intersections += 1
				if intersections >= threshold:
					return true
	return false

func circle_intersects_edge(edge: Edge, circle: Circle):
	return Geometry2D.segment_intersects_circle(
		edge.a, 
		edge.b, 
		circle.position,
		circle.radius
	)

func get_a_circle(idx=randi_range(0, polygon.size()-1)):
	var next_point = polygon[wrapi(idx+1, 0, polygon.size())]
	var prev_point = polygon[wrapi(idx-1, 0, polygon.size())]
	var starting_point = polygon[idx]
	
	var v1 = starting_point.direction_to(next_point)
	var v2 = starting_point.direction_to(prev_point)
	
	var bisector = (v1 + v2).normalized()
	var pointy = false
	
	if v1.cross(v2) < 0:
		pointy = true
		bisector *= -1
	
	var cos_theta = v1.dot(v2)
	var sin_half = sqrt((1.0 - cos_theta) * 0.5)
	if sin_half < 0.0001:
		return null
	
	var build_circle = func(radius: float):
		var d = radius
		if not pointy: d /= sin_half
		var center = starting_point + bisector * d
		var intersection = Geometry2D.get_closest_point_to_segment(center, starting_point, next_point)
		var direction = v1
		if pointy:
			intersection = starting_point
			direction = -center.direction_to(starting_point).orthogonal()
		
		return Circle.create(
			starting_point + bisector * d,
			radius - 0.1,
			intersection,
			-direction
		)
	
	var min_radius = 0.0
	var max_radius = 512.0
	while max_radius - min_radius > 0.01:
		var mid = (max_radius + min_radius) * 0.5
		var candidate = build_circle.call(mid)
		
		var progress_a = get_circle_progress_on_line(candidate, starting_point, next_point)
		var progress_b = get_circle_progress_on_line(candidate, starting_point, prev_point)
		if not pointy and (progress_a >= 1.0 or progress_b >= 1.0):
			max_radius = mid
		elif circle_intersects_polygon(candidate, 1):
			max_radius = mid
		elif get_intersecting_circles(candidate, 1):
			max_radius = mid
		else:
			min_radius = mid
	return build_circle.call(min_radius)

func get_circle_progress_on_line(circle: Circle, vector_a: Vector2, vector_b: Vector2) -> float:
	var p = Geometry2D.get_closest_point_to_segment(circle.position, vector_a, vector_b)
	var ab = vector_b - vector_a
	return (p - vector_a).dot(ab) / ab.length_squared()

func create_edge_circle(circle: Circle):
	var tangent_point = circle.intersection
	var normal = circle.position.direction_to(circle.intersection)
	var direction = circle.direction
	if normal.dot(circle.position - circle.intersection) < 0:
			normal = -normal
	
	
	var build_circle = func(radius:float):
		var offset = 2.0 * sqrt(circle.radius * radius)
		var center = tangent_point - direction * offset + normal * radius 
		return Circle.create(center, radius - 0.01)
	
	var max_radius = 512.0
	var min_radius = 1.0
	
	var smallest_circle = build_circle.call(min_radius)
	if circle_intersects_polygon(smallest_circle, 1):
		return null
	
	while max_radius - min_radius > 0.1:
		var mid = (min_radius + max_radius) * 0.5
		var candidate = build_circle.call(mid)
		if circle_intersects_polygon(candidate, 1):
			max_radius = mid
		elif get_intersecting_circles(candidate, 1):
			max_radius = mid
		else: 
			min_radius = mid
	
	var new_circle = build_circle.call(min_radius)
	circle.connections.push_back(new_circle)
	new_circle.connections.push_back(circle)
	
	return new_circle


# Add a circle into the CirclePackedPolygon.
func insert_circle(circle: Circle):
	for coordinate in circle.get_coordinates(cell_size, origin):
		circle_grid.get_or_add(coordinate, []).push_back(circle)
	circles.push_back(circle)
	return true

func get_intersecting_circles(circle_a: Circle, count=-1):
	var intersecting_circles: Dictionary[Circle, bool] = {}
	for coordinate in circle_a.get_coordinates(cell_size, origin):
		for circle_b in circle_grid.get(coordinate, []):
			if circle_a.intersects_circle(circle_b):
				intersecting_circles.set(circle_b, true)
				if count != -1 and intersecting_circles.size() == count:
					return intersecting_circles
	return intersecting_circles

func get_largest_circle(point: Vector2):
	var max_radius = 128.0
	var min_radius = 32.0
	
	# Check if the circle is inside the polygon
	if not Geometry2D.is_point_in_polygon(point, polygon):
		return null
	
	# Check if the smallest circle is valid
	var smallest_circle = Circle.create(point, min_radius)
	if circle_intersects_polygon(smallest_circle) or get_intersecting_circles(smallest_circle):
		return null
	
	# Expand max radius until we get a first intersection
	while true:
		var largest_circle = Circle.create(point, max_radius)
		if circle_intersects_polygon(largest_circle) or get_intersecting_circles(largest_circle):
			break
		max_radius *= 2.0
	
	while max_radius - min_radius > 0.1:
		var mid = (min_radius + max_radius) * 0.5
		var candidate = Circle.create(point, mid)
		
		if circle_intersects_polygon(candidate) or get_intersecting_circles(candidate, 1):
			max_radius = mid 
		else:
			min_radius = mid
	
	return Circle.create(
		point,
		min_radius
	)

func get_bisector(idx: int):
	var starting_point = polygon[wrapi(idx, 0, polygon.size())]
	var next_point = polygon[wrapi(idx+1, 0, polygon.size())]
	var previous_point = polygon[wrapi(idx-1, 0, polygon.size())]
	var v1 = starting_point.direction_to(next_point)
	var v2 = starting_point.direction_to(previous_point)
	return (v1 + v2).normalized()

#static func get_max_circle_circle_tangent(
#circle_a: Circle,
#circle_b: Circle,
#polygon: PackedVector2Array
#):
	#var d_vec = circle_b.position - circle_a.position
	#var d = d_vec.length()
	#var dir = d_vec / d
	#var perp = dir.orthogonal()
	#
	#var build_circle = func(radius: float):
		#var radius_a = circle_a.radius + radius
		#var radius_b = circle_b.radius + radius
		#var a = (pow(radius_a, 2) - pow(radius_b, 2) + pow(d, 2)) / (2*d)
		#var base = circle_a.position + dir * a
		#var h = sqrt(pow(radius_a, 2) - pow(a, 2))
		#
		#var center = base + (perp * h)
		#return Circle.new(center, radius)
