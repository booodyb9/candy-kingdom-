extends RefCounted
## Nine-patch skins with baked highlight, inset gold bevel and darker lower edges.

const INK := Color("#47113d")
const CREAM := Color("#fff4da")
const GOLD := Color("#ffdc80")
static var skins: Dictionary = {}
const SIDE := 96.0
const CORNER := 26.0

static func _rounded_distance(point: Vector2, radius: float) -> float:
	var q := point.abs() - Vector2.ONE * (SIDE * 0.5 - radius - 1.0)
	return q.max(Vector2.ZERO).length() + minf(0, maxf(q.x, q.y)) - radius

static func gloss(tone: Color, roundness := CORNER, padding := 8.0) -> StyleBoxTexture:
	var key := "%s/%s/%s" % [tone.to_html(), roundness, padding]
	if skins.has(key):
		return skins[key]
	var image := Image.create_empty(int(SIDE), int(SIDE), false, Image.FORMAT_RGBA8)
	var edge_radius := clampf(roundness, 11.0, 42.0)
	for y in int(SIDE):
		for x in int(SIDE):
			var point := Vector2(x + 0.5, y + 0.5) - Vector2.ONE * (SIDE * 0.5)
			var edge := -_rounded_distance(point, edge_radius)
			if edge < -0.6:
				continue
			var u := float(y) / SIDE
			var color := tone.lightened(0.32).lerp(tone.darkened(0.38), u)
			if edge < 2.0:
				color = Color("#6f2249").lerp(Color("#f7ae5b"), 1.0 - u)
			elif edge < 4.7:
				color = Color("#ffefa6").lerp(Color("#d17830"), u)
			elif edge < 6.5:
				color = tone.darkened(0.30)
			else:
				var band := exp(-pow((u - 0.16) * 10.0, 2.0)) * 0.42
				var shine := exp(-pow((point.x + 23.0) / 10.0, 2.0) - pow((u - 0.20) / 0.055, 2.0)) * 0.31
				color = color.lerp(Color.WHITE, band + shine)
				if edge < 8.0:
					color = color.lightened(0.18)
			image.set_pixel(x, y, Color(color, clampf(edge + 0.6, 0.0, 1.0)))
	var skin := StyleBoxTexture.new()
	skin.texture = ImageTexture.create_from_image(image)
	skin.texture_margin_left = edge_radius
	skin.texture_margin_right = edge_radius
	skin.texture_margin_top = edge_radius
	skin.texture_margin_bottom = edge_radius
	skin.content_margin_left = padding
	skin.content_margin_right = padding
	skin.content_margin_top = padding * 0.6
	skin.content_margin_bottom = padding * 0.6
	skins[key] = skin
	return skin

static func crumb(tone: Color, edge: Color, radius := 17) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = tone
	skin.border_color = edge
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(radius)
	skin.shadow_color = Color(0.25, 0.08, 0.17, 0.38)
	skin.shadow_size = 3
	skin.shadow_offset = Vector2(0, 3)
	return skin
