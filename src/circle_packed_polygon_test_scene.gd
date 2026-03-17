extends Node2D

@onready var polygon = $Polygon.points
@onready var circle_packed_polygon: CirclePackedPolygon = CirclePackedPolygon.new(polygon)

func _ready():
	print("Performing basic tests: ")
	circle_polygon_intersection_test()
	test_circle_circle_intersection_test()
	for idx in polygon.size():
		var circle = circle_packed_polygon.get_a_circle(idx)
		circle_packed_polygon.insert_circle(circle)
	queue_redraw()

func _draw():
	for circle in circle_packed_polygon.circles:
		draw_circle(circle.position, circle.radius, Color.RED, false, 4.0)


func circle_polygon_intersection_test():
	# Base polygon
	@warning_ignore("shadowed_variable")
	var polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(256, 0),
		Vector2(256, 256), Vector2(0, 256)
	])
	@warning_ignore("shadowed_variable")
	var circle_packed_polygon = CirclePackedPolygon.new(polygon)

	# --- Test 1: Circle way outside the polygon ---
	var circle = Circle.create(Vector2(-332, 32), 8.0)
	assert(circle_packed_polygon.circle_intersects_polygon(circle) == false)

	# --- Test 2: Circle clips polygon at exactly one edge ---
	circle = Circle.create(Vector2(-32, 32), 32.0)
	assert(circle_packed_polygon.circle_intersects_polygon(circle, 1) == true)

	# --- Test 3: Circle fully inside polygon, no intersections ---
	circle = Circle.create(Vector2(64, 64), 4.0)
	assert(circle_packed_polygon.circle_intersects_polygon(circle) == false)

	# Polygon offset for relative position testing
	polygon = PackedVector2Array([
		Vector2(32, 0), Vector2(288, 0),
		Vector2(288, 256), Vector2(32, 256)
	])
	circle_packed_polygon = CirclePackedPolygon.new(polygon)

	# --- Test 4: Polygon offset, circle intersects ---
	circle = Circle.create(Vector2(32, 32), 16.0)
	assert(circle_packed_polygon.circle_intersects_polygon(circle, 1) == true)
	
	# --- Test 5: Huge Circle ---
	circle = Circle.create(Vector2(32, 32), 512.0)
	assert(circle_packed_polygon.circle_intersects_polygon(circle, 1) == false)
	
	print("All circle-polygon intersection tests passed!")

func test_circle_circle_intersection_test():
	@warning_ignore("shadowed_variable")
	var polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(256, 0),
		Vector2(256, 256), Vector2(0, 256)
	])
	@warning_ignore("shadowed_variable")
	var circle_packed_polygon = CirclePackedPolygon.new(polygon)
	circle_packed_polygon.insert_circle(Circle.create(Vector2(64, 64), 32.0))
	
	# --- Test 1: One circle in the polygon, another circle intersects it
	var circle = Circle.create(Vector2(32, 64), 32.0)
	assert(circle_packed_polygon.get_intersecting_circles(circle).size() > 0)
	
	# --- Test 2: Little circle that doesn't intersect the existing one
	circle = Circle.create(Vector2(16, 64), 4.0)
	assert(circle_packed_polygon.get_intersecting_circles(circle).size() == 0)
	
	# Add another circle above the existing one
	circle_packed_polygon.insert_circle(Circle.create(Vector2(64, 32), 16.0))
	
	# --- Test 3: A circle that should intersect with both circles
	circle = Circle.create(Vector2(32, 48), 32.0)
	assert(circle_packed_polygon.get_intersecting_circles(circle).size() == 2)
	
	# --- Test 4: A circle in the exact same position, but smaller
	circle = Circle.create(Vector2(64, 64), 4.0)
	assert(circle_packed_polygon.get_intersecting_circles(circle).size() == 1)
	
	# --- Test 4: Super far huge circle
	circle = Circle.create(Vector2(256, 512), 256)
	assert(circle_packed_polygon.get_intersecting_circles(circle).size() == 0)
	
	print("All circle-circle intersection tests passed!")
