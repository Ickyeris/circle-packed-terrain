extends Node
class_name CirclePackedPolygon

# File: drawn_polygon.gd

@export var cell_size = 256.0
@export var minimum_radius = 32.0

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
	var pointy = v1.cross(v2) < 0
	if pointy:
		bisector *= -1
	
	var cos_theta = v1.dot(v2)
	var sin_half = sqrt((1.0 - cos_theta) * 0.5)
	if sin_half < 0.0001:
		return null
	
	var build_circle = func(radius: float):
		var d = radius
		if not pointy: d /= sin_half
		
		var center = starting_point + bisector * d
		var circle = Circle.create(center, radius - 0.1)
		
		circle.polygon_idx = idx
		circle.hit = get_progress_on_line(circle.position, starting_point, prev_point)
		# Collision checks
		if circle.hit >= 1.0 \
		or circle_intersects_polygon(circle, 1) \
		or get_intersecting_circles(circle, 1):
			return null
		
		return circle
	
	var min_radius = minimum_radius
	var max_radius = 512.0
	
	var smallest = build_circle.call(min_radius)
	if smallest == null:
		return null
	
	while max_radius - min_radius > 0.1:
		var mid = (max_radius + min_radius) * 0.5
		var candidate = build_circle.call(mid)
		if candidate == null:
			max_radius = mid
		else:
			min_radius = mid
	return build_circle.call(min_radius * 0.5)


func create_edge_circle(circle: Circle):
	var increment = 1 if circle.hit >= 0.95 else 0
	
	var idx = wrapi(circle.polygon_idx + increment, 0, polygon.size())
	var next_idx = wrapi(circle.polygon_idx + 1 + increment, 0, polygon.size())
	
	var p1 = polygon[idx]
	var p2 = polygon[next_idx]
	
	var starting_position =  p1.lerp(p2, circle.hit)
	var direction = p1.direction_to(p2)
	
	var min_radius = minimum_radius
	var max_radius = 256.0
	
	var ignore=[circle]
	
	var build = func(radius):
		var new_circle = find_tangent_circle(circle, radius, starting_position, direction)
		if new_circle == null: return null
		new_circle.hit = get_progress_on_line(new_circle.position, p1, p2)
		
		# Collision checks
		if new_circle.hit >= 1.0 \
		or circle_intersects_polygon(new_circle, 1) \
		or get_intersecting_circles(new_circle, 1, ignore):
			return null
		
		return new_circle
		
	var smallest_circle = build.call(min_radius)
	if smallest_circle == null:
		return null
	
	while max_radius - min_radius > 0.1:
		var mid = (min_radius + max_radius) * 0.5
		var candidate = build.call(mid)
		
		if not candidate:
			max_radius = mid
		else:
			min_radius = mid
	
	return find_tangent_circle(circle, min_radius, starting_position, direction)

func get_adjacent_circles(circle_a: Circle, circle_b: Circle):
	var adjacent_circles = [circle_b]
	var stack = []
	while true:
		var last_circle = adjacent_circles[-1]
		var circle_c: Circle = get_circle_between_circles(last_circle, circle_a)
		if circle_c == null:
			break
		stack.push_back([last_circle, circle_c])
		adjacent_circles.push_back(circle_c)
		self.insert_circle(circle_c)
	
	while not stack.is_empty():
		var item = stack.pop_front()
		var a = item[0]
		var b = item[1]
		
		var circle_c: Circle = get_circle_between_circles(a, b)
		if circle_c:
			self.insert_circle(circle_c)
			stack.push_back([circle_c, b])
			stack.push_back([a, circle_c])
	
	return adjacent_circles

func get_circle_between_circles(circle_a: Circle, circle_b: Circle):
	var d_vec = circle_b.position - circle_a.position
	var d = d_vec.length()
	var dir = d_vec / d
	var perp = dir.orthogonal()
	
	var build_circle = func(radius: float):
		var radius_a = circle_a.radius + radius
		var radius_b = circle_b.radius + radius
		var a = (pow(radius_a, 2) - pow(radius_b, 2) + pow(d, 2)) / (2*d)
		var base = circle_a.position + dir * a
		var h = sqrt(pow(radius_a, 2) - pow(a, 2))
		var center = base + (perp * h)
		var circle = Circle.create(center, radius - 1.0)
		if circle_intersects_polygon(circle, 1) \
		or get_intersecting_circles(circle, 1, [circle_a, circle_b]):
			return null
		
		if not Geometry2D.is_point_in_polygon(center, polygon):
			return null
		
		return circle
	
	var min_radius: float = minimum_radius
	var max_radius: float = 512.0
	
	var smallest = build_circle.call(min_radius)
	if smallest == null:
		return null
	
	while max_radius - min_radius > 0.1:
		var mid = (min_radius + max_radius) * 0.5
		var candidate = build_circle.call(mid)
		if not candidate:
			max_radius = mid
		else:
			min_radius = mid
	return build_circle.call(min_radius)

func get_progress_on_line(point: Vector2, vector_a: Vector2, vector_b: Vector2) -> float:
	var p = Geometry2D.get_closest_point_to_segment(point, vector_a, vector_b)
	var ab = vector_b - vector_a
	return (p - vector_a).dot(ab) / ab.length_squared()

func find_tangent_circle(circle: Circle, radius:float, line_position, line_direction):
	var d = line_direction.normalized()
	var n = Vector2(-d.y, d.x) # perpendicular
	
	var P0 = line_position + n * radius
	
	var R = circle.radius + radius
	var f = P0 - circle.position
	
	var a = 1.0
	var b = 2.0 * d.dot(f)
	var c = f.dot(f) - R * R
	
	var discriminant = b*b - 4*a*c
	if discriminant < 0:
		return null
	var sqrt_d = sqrt(discriminant)
	var center = P0 + d * ((-b + sqrt_d)/(2*a))
	
	var SHRINK = 0.01
	return Circle.create(center, radius - SHRINK)



# Add a circle into the CirclePackedPolygon.
func insert_circle(circle: Circle):
	for coordinate in circle.get_coordinates(cell_size, origin):
		circle_grid.get_or_add(coordinate, []).push_back(circle)
	circles.push_back(circle)
	return true

func get_intersecting_circles(circle_a: Circle, count=-1, exlude=[]):
	var intersecting_circles: Dictionary[Circle, bool] = {}
	for coordinate in circle_a.get_coordinates(cell_size, origin):
		for circle_b in circle_grid.get(coordinate, []):
			if circle_b in exlude:
				continue
			if circle_a.intersects_circle(circle_b):
				intersecting_circles.set(circle_b, true)
				if count != -1 and intersecting_circles.size() == count:
					return intersecting_circles
	return intersecting_circles

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
