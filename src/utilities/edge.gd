class_name Edge

var a: Vector2
var b: Vector2
var rect: Rect2

func _init(_a: Vector2, _b: Vector2):
	self.a = _a
	self.b = _b
	self.rect = Rect2(self.a, Vector2.ZERO).expand(self.b)

func get_coordinates(cell_size: float, origin=Vector2.ZERO):
	var relative_position = rect.position - origin
	var min_x = floor(relative_position.x / cell_size)
	var min_y = floor(relative_position.y / cell_size)
	var max_x = floor((relative_position.x + self.rect.size.x) / cell_size)
	var max_y = floor((relative_position.y + self.rect.size.y) / cell_size)
	
	var coordinates: Array[Vector2i] = []
	
	for x in range(min_x, max_x+1):
		for y in range(min_y, max_y+1):
			coordinates.push_back(Vector2i(x, y))
	
	return coordinates
