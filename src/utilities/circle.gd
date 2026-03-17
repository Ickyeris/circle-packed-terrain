@tool extends Node2D
class_name Circle

@export var debug: bool = false

@export var radius: float = 1.0:
	set(value):
		radius = value
		queue_redraw()
var intersection: = Vector2.ZERO
var direction: = Vector2.ZERO
var connections = []

# Factory function to create a circle
static func create(
	_position: Vector2 = Vector2.ZERO, 
	_radius: float = 1.0,
	_intersection: = Vector2.ZERO,
	_direction: = Vector2.ZERO
):
	var new_circle: = Circle.new()
	new_circle.position = _position
	new_circle.radius = _radius
	new_circle.intersection = _intersection
	new_circle.direction = _direction
	return new_circle

func _ready():
	queue_redraw()

func get_coordinates(cell_size: float, origin=Vector2.ZERO):
	var relative_position = self.position - origin
	var min_x = floor((relative_position.x - self.radius) / cell_size)
	var min_y = floor((relative_position.y - self.radius) / cell_size)
	var max_x = floor((relative_position.x + self.radius) / cell_size)
	var max_y = floor((relative_position.y + self.radius) / cell_size)
	
	var coordinates: Array[Vector2i] = []
	for x in range(min_x, max_x+1):
		for y in range(min_y, max_y+1):
			coordinates.push_back(Vector2i(x, y))
	
	return coordinates

func intersects_circle(circle: Circle, allowance=0.5):
	var distance_squared = self.position.distance_squared_to(circle.position)
	return distance_squared < pow(self.radius + circle.radius + allowance, 2)

func _draw() -> void:
	if debug:
		draw_circle(Vector2(0,0), self.radius, Color.BLUE, false, 4.0)
