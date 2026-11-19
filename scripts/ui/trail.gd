extends Control
## Coordinates are used by both the painted path and real level buttons.

const Art = preload("res://assets/candies/candy_art.gd")
const GAP := 50.0
const COUNT := 50
const PADDING := 46.0
const HEIGHT := (COUNT - 1) * GAP + PADDING * 2.0
var stops: Array[Button] = []
var scenery: Texture2D
var active := 1

func _ready() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = MOUSE_FILTER_PASS
	resized.connect(reflow)
	reflow()

func coordinate(id: float) -> Vector2:
	var y := HEIGHT - PADDING - (id - 1.0) * GAP
	var center := size.x * (0.5 + 0.29 * sin((id - 2.2) * 0.68))
	return Vector2(center, y)

func reflow() -> void:
	for index in stops.size():
		var button := stops[index]
		var point := coordinate(index + 1.0)
		button.position = point - button.size * 0.5
	queue_redraw()

func _draw() -> void:
	if scenery != null:
		var panels := 5
		var height := size.y / panels
		for index in panels:
			var region := Rect2(0, index * height, size.x, height + 1)
			draw_texture_rect(scenery, region, false)
			if index % 2:
				draw_rect(region, Color(1.0, 0.70, 0.84, 0.14))
	else:
		for index in 5:
			Art.landscape(self, Rect2(0, index * size.y / 5.0, size.x, size.y / 5.0), index)
	var ribbon := PackedVector2Array()
	var glint := PackedVector2Array()
	var shade := PackedVector2Array()
	for step in 246:
		var point := coordinate(1.0 + float(step) / 5.0)
		ribbon.append(point)
		glint.append(point - Vector2(0, 7))
		shade.append(point + Vector2(0, 10))
	draw_polyline(shade, Color("#52214e"), 37, true)
	draw_polyline(ribbon, Color("#aa5436"), 34, true)
	draw_polyline(ribbon, Color("#f4a059"), 30, true)
	draw_polyline(glint, Color("#ffd097"), 11, true)
	for id in range(1, COUNT + 1):
		var point := coordinate(id)
		draw_circle(point + Vector2(0, 5), 30, Color(0.3, 0.09, 0.23, 0.38), true, -1, true)
		if id == active:
			draw_circle(point, 34, Color(1.0, 0.74, 0.18, 0.4), true, -1, true)
			draw_arc(point, 32, 0, TAU, 32, Color("#fff1ab"), 2.3, true)
