extends Node
class_name Packer

static func get_max_circle_circle_tangent(
circle_a: Circle,
circle_b: Circle,
polygon: PackedVector2Array
):
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
		return Circle.new(center, radius)
	
	var min_size = 4.0
	var max_size = 512.0
	
	# Check if smallest circle can fit
	if circle_intersects_polygon(build_circle.call(min_size), polygon):
		return null
	
	# Check if largest circle is still too small
	if not circle_intersects_polygon(build_circle.call(max_size), polygon):
		max_size *= 2.0
	
	while max_size - min_size > 0.1:
		var mid = lerp(max_size, min_size, 0.5)
		if circle_intersects_polygon(build_circle.call(mid), polygon):
			max_size = mid
		else:
			min_size = mid
	return build_circle.call(min_size)


static func get_max_circle_line_tangent(
circle: Circle, 
polygon: PackedVector2Array
):
	const SKIN_WIDTH = 0.01
	
	var normal = circle.intersection.direction_to(circle.position)
	var direction = normal.orthogonal()
	if normal.dot(circle.position - circle.intersection) < 0:
			normal = -normal
	var tangent_point = circle.position - normal * circle.radius
	
	var build_circle = func(radius:float):
		var offset = 2.0 * sqrt(circle.radius * radius)
		var center = tangent_point + direction * offset + normal * (radius + SKIN_WIDTH)
		return Circle.new(center, radius - SKIN_WIDTH * 0.5)
	
	var min_size: float = 4.0
	var max_size: float = 512.0
	
	# If the minimum circle size cannot fit, exit
	if count_circle_polygon_intersections(build_circle.call(min_size), polygon) >= 1:
		return null
	
	# If largest circle still fits, grow it
	if count_circle_polygon_intersections(build_circle.call(max_size), polygon) < 1:
		max_size *= 2.0
	
	while max_size - min_size > 0.01:
		var mid = lerp(min_size, max_size, 0.5)
		if count_circle_polygon_intersections(build_circle.call(mid), polygon) >= 1:
			max_size = mid
		else:
			min_size = mid
	
	return build_circle.call(min_size)

# Returns a circle that is guaranteed to be inside a polygon and intersect at only one point
static func get_circle_in_polygon(polygon: PackedVector2Array):
	var starting_position = polygon[0].lerp(polygon[1], 0.5)
	var direction = -polygon[0].direction_to(polygon[1]).orthogonal()
	
	var build_circle = func(radius):
		return Circle.new(starting_position + direction * radius, radius)
	
	var min_size = 0.1
	var max_size = 512.0
	
	# If smallest circle can't fit, abort
	if count_circle_polygon_intersections(build_circle.call(min_size), polygon) > 1:
		return null
	
	# Increase max_size if even the largest circle still does not intersect the polygon
	while count_circle_polygon_intersections(
		build_circle.call(max_size),
		polygon
	) < 2: # two intersections mean the circle fully intersects at two places
		max_size *= 2.0
	
	while max_size - min_size > 0.1:
		var mid_size = lerp(min_size, max_size, 0.5)
		if count_circle_polygon_intersections(
			build_circle.call(mid_size),
			polygon
		) > 1:
			max_size = mid_size
		else:
			min_size = mid_size
	
	# Make the circle half as small to ensure only one intersection occurs.
	min_size *= 0.5
	
	return Circle.new(
		starting_position + direction * min_size,
		min_size,
		starting_position
	)

static func count_circle_polygon_intersections(circle: Circle, polygon: PackedVector2Array, threshold=2):
	# Check is polygon has enough points
	if polygon.size() <= 2:
		return 0
	
	var count: = 0
	for idx in polygon.size():
		var next_idx = wrapi(idx+1, 0, polygon.size())
		var intersects = Geometry2D.segment_intersects_circle(
			polygon[idx], 
			polygon[next_idx], 
			circle.position, 
			circle.radius
		)
		if intersects != -1:
			count += 1
		if threshold != -1 and count >= threshold: return count
	return count

# Checks if a circle intersects a polygon
static func circle_intersects_polygon(circle: Circle, polygon: PackedVector2Array):
	for i in polygon.size():
		var a = polygon[i]
		var b = polygon[(i + 1) % polygon.size()]
		var closest = Geometry2D.get_closest_point_to_segment(circle.position, a, b)
		if circle.position.distance_squared_to(closest) <= pow(circle.radius, 2):
			return true
	return false
