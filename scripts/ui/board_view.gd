extends Control

const Art = preload("res://assets/candies/candy_art.gd")
const Glaze = preload("res://scripts/ui/glaze.gd")
var engine
var display: Dictionary = {}
var frame: Dictionary = {}
var progress := 1.0
var selected := -1
var focus_cell := -1
var busy := false
var animate := true
var clock := 0.0
var pointer := Vector2.ZERO
var pressed := false
var hovered_cell := -1
signal cell_tapped(index: int)
signal swipe_made(a: int, b: int)

func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	Art.prepare()

func _process(delta: float) -> void:
	if animate and not busy and engine != null and selected >= 0:
		clock += delta
		queue_redraw()

func square() -> float:
	return floorf(minf((size.x - 23) / engine.width, (size.y - 23) / engine.height))

func field() -> Rect2:
	var extent := Vector2(engine.width, engine.height) * square()
	return Rect2((size - extent) / 2.0, extent)

func at(point: Vector2) -> int:
	if engine == null or not field().has_point(point):
		return -1
	var cell := Vector2i((point - field().position) / square())
	return cell.y * engine.width + cell.x

func center(index: int) -> Vector2:
	return field().position + (Vector2(index % engine.width, index / engine.width) + Vector2.ONE * 0.5) * square()

func _gui_input(event: InputEvent) -> void:
	if busy or engine == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			pointer = event.position
			pressed = true
			return
		if not pressed:
			return
		pressed = false
		var start := at(pointer)
		if start < 0:
			return
		var displacement: Vector2 = event.position - pointer
		if displacement.length() < square() * 0.32:
			cell_tapped.emit(start)
			return
		var step := 0
		if absf(displacement.x) > absf(displacement.y):
			step = 1 if displacement.x > 0 else -1
		else:
			step = engine.width if displacement.y > 0 else -engine.width
		if engine.adjacent(start, start + step):
			swipe_made.emit(start, start + step)
	elif event is InputEventKey and event.pressed:
		if focus_cell < 0:
			focus_cell = 0
		var target := focus_cell
		match event.keycode:
			KEY_LEFT: target -= 1
			KEY_RIGHT: target += 1
			KEY_UP: target -= engine.width
			KEY_DOWN: target += engine.width
			KEY_ENTER, KEY_SPACE: cell_tapped.emit(focus_cell)
			_: return
		if engine.adjacent(focus_cell, target):
			focus_cell = target
		accept_event()
		queue_redraw()

func _draw() -> void:
	if engine == null or display.is_empty():
		return
	var board := field()
	var step := square()
	var rim := Glaze.gloss(Color("#fa8d80"), 22.0, 4.0)
	draw_style_box(rim, board.grow(10))
	var border := Glaze.crumb(Color("#192448"), Color("#fff0d7"), 10)
	draw_style_box(border, board.grow(4))
	for index in display.grid.size():
		var point := center(index)
		var tile := Rect2(point - Vector2.ONE * (step / 2.0 - 1), Vector2.ONE * (step - 2))
		var alternate: bool = (index % engine.width + index / engine.width) % 2 == 0
		draw_rect(tile, Color("#303862") if alternate else Color("#252d54"))
		if display.jelly[index] > 0:
			draw_rect(tile.grow(-2), Color(0.35, 0.88, 1.0, 0.28))
			draw_rect(tile.grow(-3), Color("#7ae9ff"), false, 2)
			if display.jelly[index] == 2:
				draw_rect(tile.grow(-7), Color("#b7f6ff"), false, 1)
		if index == selected or (has_focus() and index == focus_cell):
			draw_rect(tile.grow(-2), Color("#fff2ac"), false, 2.5)
		if display.blocks[index] > 0:
			draw_rect(tile.grow(-4), Color("#854750"))
			draw_rect(tile.grow(-6), Color("#bc755f"), false, 2)
			draw_circle(point, step * 0.16, Color("#60314a"), true, -1, true)
			for pip in display.blocks[index]:
				draw_circle(point + Vector2(pip * 7 - (display.blocks[index] - 1) * 3.5, 0), 2.8, Color("#ffd196"), true, -1, true)
	var info: Dictionary = frame.get("data", {})
	for index in display.grid.size():
		var piece: int = display.grid[index]
		if piece < 0:
			continue
		var point := center(index)
		if info.get("origins", {}).has(index):
			point = center(info.origins[index]).lerp(point, progress)
		if info.get("offsets", {}).has(index):
			point.y += float(info.offsets[index]) * step * (1.0 - progress)
		var extent := step * 1.09
		if index == selected and animate:
			extent *= 1.0 + sin(clock * 7.5) * 0.075
		Art.paint_piece(self, piece, point, extent)
		if display.locks[index] > 0:
			draw_arc(point, step * 0.36, 0, TAU, 24, Color("#f7dc98"), 2, true)
			draw_line(point + Vector2(-0.29, -0.25) * step, point + Vector2(0.29, 0.25) * step, Color("#f7dc98"), 3, true)
	if frame.get("kind") == "clear" and progress < 1.0:
		for index in info.cells + info.damaged:
			for particle in 5:
				var angle := TAU * particle / 5.0 + int(index) * 0.11
				var position := center(index) + Vector2.from_angle(angle) * step * (0.14 + 0.48 * progress)
				draw_circle(position, (1.0 - progress) * 4.6, Color(1, 0.86, 0.55, 1.0 - progress), true, -1, true)
		for index in info.powers:
			draw_arc(center(index), step * (0.22 + progress * 0.9), 0, TAU, 24, Color(1, 0.93, 0.6, 1.0 - progress), 3, true)
