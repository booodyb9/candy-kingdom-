extends Node2D
## Original candy silhouettes and baked lighting for the compatibility renderer.

const COLORS := [Color("#ff4566"), Color("#48cfff"), Color("#83e542"), Color("#ffe35c"), Color("#ce71ff"), Color("#ffa140")]
const SIDE := 96
static var candies: Array[Texture2D] = []

static func prepare() -> void:
	if not candies.is_empty():
		return
	for kind in COLORS.size():
		var image := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RGBA8)
		for y in SIDE:
			for x in SIDE:
				var p := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2.ONE * SIDE / 2.0) / (SIDE / 2.0)
				var d := _shape(p, kind)
				var alpha := clampf(0.65 - d * SIDE / 2.0, 0.0, 1.0)
				if alpha <= 0:
					continue
				var normal := Vector2(_shape(p + Vector2(0.007, 0), kind) - d, _shape(p + Vector2(0, 0.007), kind) - d).normalized()
				var bevel := clampf(1.0 + d * 5.2, 0.0, 1.0)
				var ray := Vector2(-0.66, -0.75)
				var lambert := normal.dot(ray)
				var base: Color = COLORS[kind]
				var color_value := base.darkened(clampf(p.y * 0.32 + 0.1, 0.0, 0.54))
				color_value = color_value.lerp(Color.WHITE, clampf(bevel * lambert * 0.32, 0.0, 0.4))
				color_value = color_value.darkened(bevel * maxf(0, -lambert) * 0.37)
				var spot := Vector2((p.x + 0.28) / 0.31, (p.y + 0.44 - p.x * 0.16) / 0.17)
				var gloss := exp(-spot.length_squared() * 1.6) * clampf((-d - 0.015) * 19.0, 0, 1)
				color_value = color_value.lerp(Color("#fff8ed"), gloss * 0.83)
				var rim := exp(-pow((d + 0.075) * 29.0, 2.0)) * maxf(lambert, 0.0)
				color_value = color_value.lerp(Color.WHITE, rim * 0.3)
				if kind == 0 and p.y < -0.35 and absf(p.x) < 0.24 and d < -0.02:
					color_value = color_value.lerp(Color("#bffc7d"), 0.32)
				image.set_pixel(x, y, Color(color_value, alpha))
		candies.append(ImageTexture.create_from_image(image))

static func _ellipse(p: Vector2, center: Vector2, radius: Vector2) -> float:
	return ((p - center) / radius).length() * minf(radius.x, radius.y) - minf(radius.x, radius.y)

static func _shape(p: Vector2, kind: int) -> float:
	match kind:
		0:
			# Two shoulders taper into a strawberry tip.
			var q := Vector2(p.x * (1.0 + maxf(p.y, 0) * 0.83), p.y)
			return minf(_ellipse(q, Vector2(-0.22, -0.1), Vector2(0.58, 0.72)), _ellipse(q, Vector2(0.22, -0.1), Vector2(0.58, 0.72)))
		1:
			return maxf((absf(p.x) + absf(p.y)) * 0.707 - 0.55, maxf(absf(p.x), absf(p.y)) - 0.70)
		2:
			return minf(_ellipse(p, Vector2(-0.24, 0.04), Vector2(0.55, 0.68)), _ellipse(p, Vector2(0.24, 0.04), Vector2(0.55, 0.68)))
		3:
			return _ellipse(p.rotated(-0.39), Vector2.ZERO, Vector2(0.83, 0.54))
		4:
			var d := _ellipse(p, Vector2(0, 0.46), Vector2(0.29, 0.32))
			for center in [Vector2(-0.28, 0.15), Vector2(0.28, 0.15), Vector2(-0.42, -0.28), Vector2.ZERO + Vector2(0, -0.36), Vector2(0.42, -0.28)]:
				d = minf(d, _ellipse(p, center, Vector2(0.34, 0.36)))
			return d
		_:
			return p.length() - 0.75

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
