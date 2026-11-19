extends Node2D
## Original candy silhouettes and baked lighting for the compatibility renderer.

const COLORS := [Color("#ff1641"), Color("#079ef8"), Color("#6cce12"), Color("#ffc520"), Color("#b028f7"), Color("#ff860d")]
const SIDE := 112
const LIGHT := Vector3(-0.48, -0.66, 0.57)
const HALF_LIGHT := Vector3(-0.27, -0.37, 0.89)
static var candies: Array[Texture2D] = []

static func prepare() -> void:
	if not candies.is_empty():
		return
	for kind in COLORS.size():
		var image := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RGBA8)
		var heights := PackedFloat32Array()
		heights.resize(SIDE * SIDE)
		for y in SIDE:
			for x in SIDE:
				var p := _point(x, y)
				heights[y * SIDE + x] = _height(p, kind)
		for y in range(1, SIDE - 1):
			for x in range(1, SIDE - 1):
				var p := _point(x, y)
				var distance := _shape(p, kind)
				var opacity := clampf(0.50 - distance * SIDE * 0.5, 0, 1)
				if opacity <= 0:
					continue
				var i := y * SIDE + x
				var normal := Vector3(33.0 * (heights[i - 1] - heights[i + 1]),
					33.0 * (heights[i - SIDE] - heights[i + SIDE]), 1.0).normalized()
				var light := maxf(0.0, normal.dot(LIGHT))
				var glint := pow(maxf(0.0, normal.dot(HALF_LIGHT)), 35.0)
				var halo := pow(maxf(0.0, normal.dot(HALF_LIGHT)), 6.0)
				var body: Color = COLORS[kind]
				var color := body.darkened(clampf(0.50 - light * 0.65 + p.y * 0.13, 0.0, 0.68))
				var edge := exp(-pow((distance + 0.075) * 26.0, 2.0))
				color = color.lerp(body.lightened(0.55), edge * (0.15 + light * 0.38))
				color = color.lerp(Color("#fff5dc"), minf(0.92, glint * 0.88 + halo * 0.16))
				if kind == 1:
					var face := (p.abs().x + p.abs().y) * 0.72
					color = color.lerp(Color("#74eafa"), clampf(0.27 - p.y * 0.27, 0, 0.48) if face < 0.45 else edge * 0.53)
				var reflection := Vector2((p.x + 0.30) / 0.22, (p.y + 0.44 + p.x * 0.18) / 0.11)
				var reflection_value := exp(-reflection.length_squared() * 1.25) * clampf(-distance * 15.0, 0, 1)
				color = color.lerp(Color("#fffef3"), reflection_value * 0.73)
				image.set_pixel(x, y, Color(color, opacity))
		candies.append(ImageTexture.create_from_image(image))

static func _point(x: int, y: int) -> Vector2:
	return (Vector2(x + 0.5, y + 0.5) - Vector2.ONE * (SIDE * 0.5)) / (SIDE * 0.5)

static func _ellipse(p: Vector2, center: Vector2, radius: Vector2) -> float:
	return (((p - center) / radius).length() - 1.0) * minf(radius.x, radius.y)

static func _shape(p: Vector2, kind: int) -> float:
	match kind:
		0:
			var upper := absf(p.x)
			if p.y + upper < 0.02:
				return (Vector2(upper - 0.28, p.y + 0.25).length() - 0.43) * 0.9
			var diagonal := (upper + p.y) * 0.70 - 0.52
			var rounding := _ellipse(p, Vector2(0, 0.07), Vector2(0.75, 0.69))
			return maxf(diagonal, rounding)
		1:
			return maxf((absf(p.x) + absf(p.y)) * 0.707 - 0.60, maxf(absf(p.x), absf(p.y)) - 0.76)
		2:
			return _ellipse(p, Vector2(0, 0.05), Vector2(0.72, 0.70))
		3:
			var radius := p.length()
			var wedge := absf(fposmod(p.angle() + PI / 2 + PI / 5, TAU / 5) - PI / 5)
			var edge := 0.48 + 0.29 * pow(1.0 - wedge / (PI / 5), 1.5)
			return radius - edge
		4:
			var d := p.length() - 0.32
			for center in [Vector2(-0.33, -0.20), Vector2(0.01, -0.42), Vector2(0.34, -0.20),
				Vector2(-0.36, 0.19), Vector2(0.33, 0.18), Vector2(0.00, 0.46)]:
				d = minf(d, (p - center).length() - 0.30)
			return d
		_:
			return p.length() - 0.75

static func _height(p: Vector2, kind: int) -> float:
	var depth := -_shape(p, kind)
	if depth <= 0:
		return 0.0
	if kind == 1:
		return minf(depth * 1.8, 0.30) + depth * 0.09
	var volume := sqrt(clampf(depth * 1.54, 0, 1)) * 0.56
	if kind == 2:
		volume += 0.055 * cos(p.x * 12.0) * clampf(depth * 5.0, 0, 1)
	elif kind == 5:
		var coil := cos(p.length() * 17.0 - p.angle() * 0.94)
		volume += coil * 0.043 * clampf(depth * 5.0, 0, 1)
	return volume

static func paint_piece(canvas: CanvasItem, piece: int, center: Vector2, extent: float, alpha := 1.0) -> void:
	if piece < 0:
		return
	var kind := piece % 8
	var power := piece / 8
	var half := Vector2.ONE * extent * 0.5
	if power == 4:
		canvas.draw_circle(center + Vector2(0, 3), extent * 0.38, Color(0.11, 0.03, 0.20, alpha), true, -1, true)
		for index in 6:
			var angle := index * TAU / 6.0
			canvas.draw_circle(center + Vector2.from_angle(angle) * extent * 0.19, extent * 0.14, Color(COLORS[index], alpha), true, -1, true)
		canvas.draw_circle(center, extent * 0.07, Color(1, 1, 1, alpha), true, -1, true)
		return
	canvas.draw_circle(center + Vector2(0, extent * 0.085), extent * 0.35, Color(0.05, 0.02, 0.13, alpha * 0.25), true, -1, true)
	canvas.draw_texture_rect(candies[kind], Rect2(center - half, half * 2), false, Color(1, 1, 1, alpha))
	if power == 1 or power == 2:
		var axis := Vector2.RIGHT if power == 1 else Vector2.DOWN
		canvas.draw_line(center - axis * extent * 0.29, center + axis * extent * 0.29, Color(1, 0.95, 0.77, alpha), extent * 0.09, true)
	elif power == 3:
		canvas.draw_circle(center, extent * 0.16, Color(0.31, 0.08, 0.38, alpha), true, -1, true)
		canvas.draw_arc(center, extent * 0.16, 0, TAU, 22, Color(1, 0.93, 0.70, alpha), 2, true)
		canvas.draw_circle(center + Vector2(-2, -2), extent * 0.044, Color(1, 0.95, 0.77, alpha), true, -1, true)

static func landscape(canvas: CanvasItem, rect: Rect2, chapter := 0) -> void:
	var size := rect.size
	var origin := rect.position
	var sky := Color("#376fc1").lerp(Color("#285b91"), float(chapter % 5) * 0.12)
	for step in 30:
		var tint := sky.lerp(Color("#dd7ab8"), float(step) / 38.0)
		canvas.draw_rect(Rect2(origin + Vector2(0, size.y * step / 30.0), Vector2(size.x, size.y / 30.0 + 1)), tint)
	var moon := origin + size * Vector2(0.70, 0.19)
	for radius in [88, 69, 52]:
		canvas.draw_circle(moon, size.x * radius / 480.0, Color(1, 0.76, 0.86, 0.11), true, -1, true)
	canvas.draw_circle(moon, size.x * 0.077, Color("#ffbdcc"), true, -1, true)
	for index in 28:
		var star := origin + Vector2(size.x * fposmod(index * 0.618 + 0.13, 1.0), size.y * fposmod(index * 0.381, 0.66))
		var tint := Color(1, 0.88, 0.99, 0.32 + 0.15 * (index % 3))
		canvas.draw_circle(star, 1.2 + index % 3 * 0.72, tint, true, -1, true)
	for index in 7:
		var hill := origin + Vector2(size.x * (index - 1) / 5.0, size.y * (0.94 + float(index % 3) * 0.06))
		canvas.draw_circle(hill, size.x * (0.25 + index % 3 * 0.035), sky.lerp(Color("#c35fba"), 0.38 + 0.09 * index), true, -1, true)
	_castle(canvas, origin + size * Vector2(0.28, 0.73), size.x / 480.0)
	for index in 5:
		var lollipop := origin + size * Vector2(0.06 + index * 0.23, 0.82 + index % 2 * 0.083)
		var radius := size.x * (0.026 + index % 3 * 0.007)
		canvas.draw_line(lollipop, lollipop + Vector2(-radius * 0.25, size.y * 0.12), Color("#e2b6da"), radius * 0.2, true)
		canvas.draw_circle(lollipop, radius, Color("#eb84c7"), true, -1, true)
		canvas.draw_arc(lollipop, radius * 0.67, -2.7, 2.0, 20, Color("#ffc5e1"), radius * 0.20, true)
		canvas.draw_circle(lollipop, radius * 0.29, Color("#ffd4e8"), true, -1, true)

static func _castle(canvas: CanvasItem, base: Vector2, scale_value: float) -> void:
	for index in 3:
		var middle := index == 1
		var x := float(index - 1) * 51.0
		var h := 110.0 if middle else 76.0
		var w := 49.0 if middle else 34.0
		var tip := base + Vector2(x, -h - w * 0.86) * scale_value
		var top := tip + Vector2(0, w * 0.86) * scale_value
		canvas.draw_rect(Rect2(top - Vector2(w * 0.5, 0) * scale_value, Vector2(w, h) * scale_value), Color("#dc9ecc"))
		canvas.draw_colored_polygon(PackedVector2Array([tip, top + Vector2(-w * 0.62, 0) * scale_value,
			top + Vector2(w * 0.62, 0) * scale_value]), Color("#96388e"))
		canvas.draw_circle(tip, 4 * scale_value, Color("#ffd48d"), true, -1, true)
		var window := top + Vector2(0, h * 0.34) * scale_value
		canvas.draw_circle(window, w * 0.15 * scale_value, Color("#6b397f"), true, -1, true)
		canvas.draw_rect(Rect2(window - Vector2(w * 0.15, 0) * scale_value, Vector2(w * 0.3, 10) * scale_value), Color("#6b397f"))
