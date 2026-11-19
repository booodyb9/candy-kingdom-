extends Control

const Art = preload("res://assets/candies/candy_art.gd")
var kind := ""
var tint := Color("#fff5cf")
var piece := -1

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var unit := minf(size.x, size.y) / 48.0
	if unit <= 0.0:
		return
	var center := size * 0.5
	if piece >= 0:
		Art.paint_piece(self, piece, center, unit * 49)
		return
	draw_set_transform(center, 0.0, Vector2.ONE * unit)
	var shadow := Color("#61234b")
	match kind:
		"heart":
			Art.paint_piece(self, 0, Vector2.ZERO, 49)
		"coin":
			draw_circle(Vector2(1, 2), 21, Color("#a85511"), true, -1.0, true)
			draw_circle(Vector2.ZERO, 20, Color("#ffca2d"), true, -1.0, true)
			draw_arc(Vector2.ZERO, 17, 0, TAU, 40, Color("#fff4a5"), 2, true)
			draw_arc(Vector2.ZERO, 12, -0.65, 3.8, 28, Color("#e77c18"), 3, true)
			draw_line(Vector2(-4, -6), Vector2(3, 6), Color("#ffef93"), 4, true)
		"crown":
			var shape := PackedVector2Array([Vector2(-21,-10), Vector2(-10,-4), Vector2(0,-18), Vector2(10,-4), Vector2(21,-10), Vector2(15,14), Vector2(-15,14)])
			draw_colored_polygon(shape, Color("#ffc33f"))
			draw_polyline(PackedVector2Array([Vector2(-16,10), Vector2(16,10)]), Color("#e47c20"), 4, true)
			for pos in [Vector2(-21,-11), Vector2(0,-18), Vector2(21,-11)]:
				draw_circle(pos, 4.4, Color("#fff08f"), true, -1, true)
			draw_circle(Vector2(0,4), 4.4, Color("#df479e"), true, -1, true)
		"hammer":
			draw_line(Vector2(-14, 17), Vector2(7, -7), shadow, 10, true)
			draw_line(Vector2(-15, 15), Vector2(6, -8), Color("#ffb84c"), 7, true)
			draw_set_transform(center, -0.56, Vector2.ONE * unit)
			draw_rect(Rect2(-13,-16,30,14), Color("#69ddfc"))
			draw_rect(Rect2(-16,-17,7,16), Color("#fce6a5"))
			draw_rect(Rect2(14,-17,7,16), Color("#ff977a"))
			draw_line(Vector2(-8,-13), Vector2(13,-13), Color.WHITE, 2.4, true)
		"shuffle":
			for side in [-1, 1]:
				var k := float(side)
				var points := PackedVector2Array([Vector2(-17, -9*k), Vector2(-6,-9*k), Vector2(6,9*k), Vector2(17,9*k)])
				var color := Color("#c7fb64") if side > 0 else Color("#ffcc58")
				draw_polyline(points, color, 5, true)
				draw_colored_polygon(PackedVector2Array([Vector2(13, 9*k-6), Vector2(21,9*k), Vector2(13,9*k+6)]), color)
		"color":
			Art.paint_piece(self, 32, Vector2.ZERO, 53)
		"pause":
			for x in [-9, 9]:
				draw_line(Vector2(x, -12), Vector2(x, 12), tint, 6.5, true)
				draw_circle(Vector2(x, -12), 3.2, tint, true, -1, true)
				draw_circle(Vector2(x, 12), 3.2, tint, true, -1, true)
		"play":
			draw_colored_polygon(PackedVector2Array([Vector2(-12,-17), Vector2(17,0), Vector2(-12,17)]), tint)
		"map":
			draw_colored_polygon(PackedVector2Array([Vector2(-18,-11),Vector2(-6,-15),Vector2(6,-11),Vector2(18,-15),Vector2(18,11),Vector2(6,15),Vector2(-6,11),Vector2(-18,15)]), Color("#fff1b2"))
			draw_polyline(PackedVector2Array([Vector2(-13,6),Vector2(-7,-5),Vector2(5,4),Vector2(12,-6)]), Color("#8b503a"), 2.8, true)
			draw_circle(Vector2(12,-6), 4, Color("#d64d73"), true, -1, true)
		"lock":
			draw_arc(Vector2(0,-4), 9, PI, TAU, 16, tint, 4, true)
			draw_rect(Rect2(-12,-4,24,19), tint)
			draw_circle(Vector2(0,4), 2.5, shadow, true, -1, true)
		"jelly":
			draw_rect(Rect2(-16,-13,32,26), Color("#63dceb"))
			draw_rect(Rect2(-13,-10,26,20), Color("#aefcff"), false, 3)
		"block":
			draw_rect(Rect2(-16,-13,32,26), Color("#623143"))
			draw_rect(Rect2(-14,-11,28,22), Color("#bf785b"), false, 3)
			draw_circle(Vector2.ZERO, 4, Color("#ffe2a6"), true, -1, true)
		_:
			pass
	draw_set_transform(Vector2.ZERO)
