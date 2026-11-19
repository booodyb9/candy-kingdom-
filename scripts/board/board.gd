extends RefCounted
## Deterministic, renderer-independent board. Coordinates are flat, row-major indices.

enum Power { NORMAL, ROW, COLUMN, BOMB, RAINBOW }
enum Phase { IDLE, SWAPPING, MATCH_CHECK, REMOVING, FALLING, REFILLING, CASCADE, COMPLETE, FAILED }
const EMPTY := -1
const RADIX := 8
const MAX_CASCADES := 48

var width: int
var height: int
var colors: int
var moves: int
var score := 0
var phase := Phase.IDLE
var grid := PackedInt32Array()
var jelly := PackedInt32Array()
var blocks := PackedInt32Array()
var locks := PackedInt32Array()
var collected := PackedInt32Array([0, 0, 0, 0, 0, 0])
var level: Dictionary
var random := RandomNumberGenerator.new()

func _init(definition: Dictionary, seed_value: int) -> void:
	level = definition
	width = int(level.get("width", 8))
	height = int(level.get("height", 8))
	colors = int(level.get("colors", 6))
	moves = int(level.get("moves", 25))
	random.seed = seed_value
	grid.resize(width * height)
	jelly.resize(grid.size())
	blocks.resize(grid.size())
	locks.resize(grid.size())
	for entry in level.get("tiles", []):
		var index := int(entry[1]) * width + int(entry[0])
		match str(entry[2]):
			"jelly": jelly[index] = int(entry[3])
			"lock": locks[index] = int(entry[3])
			"block": blocks[index] = int(entry[3])
	_make_playable()

static func color(piece: int) -> int:
	return piece % RADIX

static func power(piece: int) -> int:
	return piece / RADIX

func _make_playable() -> void:
	for attempt in range(128):
		grid.fill(EMPTY)
		for index in grid.size():
			if blocks[index] > 0:
				continue
			var candidates: Array[int] = []
			for kind in colors:
				if index % width >= 2 and grid[index - 1] == kind and grid[index - 2] == kind:
					continue
				if index >= 2 * width and grid[index - width] == kind and grid[index - 2 * width] == kind:
					continue
				candidates.append(kind)
			grid[index] = candidates[random.randi_range(0, candidates.size() - 1)]
		if not legal_moves(true).is_empty():
			return
	push_error("Level %s has no playable starting layout." % str(level.get("id", "?")))

func snapshot() -> Dictionary:
	return {"grid": grid.duplicate(), "jelly": jelly.duplicate(), "blocks": blocks.duplicate(),
		"locks": locks.duplicate(), "moves": moves, "score": score,
		"collected": collected.duplicate()}

func _frame(frames: Array, kind: String, data := {}) -> void:
	frames.append({"kind": kind, "board": snapshot(), "data": data})

func adjacent(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= grid.size() or b >= grid.size():
		return false
	return absi(a % width - b % width) + absi(a / width - b / width) == 1

func selectable(index: int) -> bool:
	return index >= 0 and index < grid.size() and grid[index] != EMPTY and locks[index] == 0

func _swap(a: int, b: int) -> void:
	var saved := grid[a]
	grid[a] = grid[b]
	grid[b] = saved

func _special_pair(a: int, b: int) -> bool:
	var first := power(grid[a])
	var second := power(grid[b])
	return first == Power.RAINBOW or second == Power.RAINBOW or (first > 0 and second > 0)

func _same(index: int, kind: int) -> bool:
	return grid[index] != EMPTY and power(grid[index]) != Power.RAINBOW and color(grid[index]) == kind

func _matches_here(index: int) -> bool:
	if grid[index] == EMPTY or power(grid[index]) == Power.RAINBOW:
		return false
	var kind := color(grid[index])
	for step in [1, width]:
		var offset := index % width if step == 1 else index / width
		var length := width if step == 1 else height
		var count := 1
		for direction in [-1, 1]:
			for distance in [1, 2]:
				var position: int = offset + direction * distance
				if position < 0 or position >= length or not _same(index + direction * distance * step, kind):
					break
				count += 1
		if count >= 3:
			return true
	return false

func _scan(start: int, step: int, length: int, runs: Array) -> void:
	var begin := 0
	while begin < length:
		var index := start + begin * step
		var end := begin + 1
		if grid[index] != EMPTY and power(grid[index]) != Power.RAINBOW:
			while end < length and _same(start + end * step, color(grid[index])):
				end += 1
			if end - begin >= 3:
				var cells: Array[int] = []
				for offset in range(begin, end):
					cells.append(start + offset * step)
				runs.append({"cells": cells, "power": Power.ROW if step == 1 else Power.COLUMN})
		begin = end

func matches() -> Array:
	var runs: Array = []
	for y in height:
		_scan(y * width, 1, width, runs)
	for x in width:
		_scan(x, width, height, runs)
	return runs

func legal_moves(first_only := false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for a in grid.size():
		if not selectable(a):
			continue
		for b in [a + 1, a + width]:
			if not adjacent(a, b) or not selectable(b):
				continue
			var valid := _special_pair(a, b)
			if not valid:
				_swap(a, b)
				valid = _matches_here(a) or _matches_here(b)
				_swap(a, b)
			if valid:
				result.append(Vector2i(a, b))
				if first_only:
					return result
	return result

func _plan(runs: Array, preferred: Array) -> Dictionary:
	var groups: Array = []
	for run in runs:
		var group := {"cells": {}, "longest": run.cells.size(), "axis": run.power, "cross": false}
		for cell in run.cells:
			group.cells[cell] = true
		for index in range(groups.size() - 1, -1, -1):
			var previous: Dictionary = groups[index]
			var overlap := false
			for cell in previous.cells:
				if group.cells.has(cell):
					overlap = true
					break
			if overlap:
				group.cells.merge(previous.cells)
				group.longest = maxi(group.longest, previous.longest)
				group.cross = true
				groups.remove_at(index)
		groups.append(group)
	var hits := {}
	var created := {}
	for group in groups:
		hits.merge(group.cells)
		var effect: int = Power.NORMAL
		if group.longest >= 5:
			effect = Power.RAINBOW
		elif group.cross:
			effect = Power.BOMB
		elif group.longest == 4:
			effect = int(group.axis)
		if effect == Power.NORMAL:
			continue
		var candidates: Array = preferred + group.cells.keys()
		for index in candidates:
			if group.cells.has(index) and selectable(index) and power(grid[index]) == Power.NORMAL:
				created[index] = color(grid[index]) + effect * RADIX
				break
	return {"hits": hits, "created": created}

func _area(center: int, radius: int, hits: Dictionary) -> void:
	var x := center % width
	var y := center / width
	for row in range(maxi(0, y - radius), mini(height, y + radius + 1)):
		for column in range(maxi(0, x - radius), mini(width, x + radius + 1)):
			hits[row * width + column] = true

func _line(index: int, effect: int, hits: Dictionary) -> void:
	if effect == Power.ROW:
		for x in width:
			hits[(index / width) * width + x] = true
	else:
		for y in height:
			hits[y * width + index % width] = true

func _color_hits(kind: int, hits: Dictionary) -> void:
	for index in grid.size():
		if grid[index] != EMPTY and color(grid[index]) == kind:
			hits[index] = true

func _combo(a: int, b: int) -> Dictionary:
	var first := power(grid[a])
	var second := power(grid[b])
	var hits := {a: true, b: true}
	if first == Power.RAINBOW and second == Power.RAINBOW:
		for index in grid.size():
			hits[index] = true
	elif first == Power.RAINBOW or second == Power.RAINBOW:
		var other := b if first == Power.RAINBOW else a
		var kind := color(grid[other])
		var effect := power(grid[other])
		var targets := {}
		_color_hits(kind, targets)
		hits.merge(targets)
		for index in targets:
			if effect == Power.BOMB:
				_area(index, 1, hits)
			elif effect in [Power.ROW, Power.COLUMN]:
				_line(index, effect, hits)
	elif first == Power.BOMB and second == Power.BOMB:
		_area(b, 2, hits)
	elif first == Power.BOMB or second == Power.BOMB:
		for distance in range(-1, 2):
			if b / width + distance >= 0 and b / width + distance < height:
				_line(b + width * distance, Power.ROW, hits)
			if b % width + distance >= 0 and b % width + distance < width:
				_line(b + distance, Power.COLUMN, hits)
	else:
		_line(b, Power.ROW, hits)
		_line(b, Power.COLUMN, hits)
	return hits

func _expand(hits: Dictionary, created: Dictionary, activated: Dictionary) -> Dictionary:
	var queue := hits.keys()
	var cursor := 0
	while cursor < queue.size():
		var index: int = queue[cursor]
		cursor += 1
		if created.has(index) or activated.has(index) or grid[index] == EMPTY:
			continue
		var effect := power(grid[index])
		if effect == Power.NORMAL:
			continue
		activated[index] = true
		var extra := {}
		match effect:
			Power.ROW, Power.COLUMN: _line(index, effect, extra)
			Power.BOMB: _area(index, int(level.get("bomb_radius", 1)), extra)
			Power.RAINBOW: _color_hits(color(grid[index]), extra)
		for target in extra:
			if not hits.has(target):
				hits[target] = true
				queue.append(target)
	return hits

func _clear(hits: Dictionary, created: Dictionary, activated: Dictionary, depth: int, frames: Array) -> void:
	phase = Phase.REMOVING
	_expand(hits, created, activated)
	var damaged := {}
	var removed: Array[int] = []
	for index in hits:
		if jelly[index] > 0:
			jelly[index] -= 1
		if blocks[index] > 0:
			damaged[index] = true
			continue
		if grid[index] == EMPTY:
			continue
		collected[color(grid[index])] += 1
		removed.append(index)
		if locks[index] > 0:
			locks[index] -= 1
			if locks[index] > 0:
				continue
		grid[index] = created.get(index, EMPTY)
		for neighbor in [index - width, index + width, index - 1, index + 1]:
			if adjacent(index, neighbor) and blocks[neighbor] > 0:
				damaged[neighbor] = true
	for index in damaged:
		blocks[index] -= 1
	score += (removed.size() * 10 + damaged.size() * 15) * mini(depth, 5)
	_frame(frames, "clear", {"cells": removed, "damaged": damaged.keys(), "combo": depth, "powers": activated.keys()})

func _fall(frames: Array) -> void:
	phase = Phase.FALLING
	var drops := {}
	for x in width:
		var sink := height - 1
		for y in range(height - 1, -1, -1):
			var from := y * width + x
			if blocks[from] > 0 or locks[from] > 0:
				sink = y - 1
				continue
			if grid[from] == EMPTY:
				continue
			var to := sink * width + x
			if to != from:
				grid[to] = grid[from]
				grid[from] = EMPTY
				drops[to] = from
			sink -= 1
	if not drops.is_empty():
		_frame(frames, "fall", {"origins": drops})
	phase = Phase.REFILLING
	var offsets := {}
	for x in width:
		var entry_row := -1
		var gap := 0
		for y in height:
			var index := y * width + x
			if blocks[index] > 0 or locks[index] > 0:
				entry_row = y
				gap = 0
			elif grid[index] == EMPTY:
				grid[index] = random.randi_range(0, colors - 1)
				offsets[index] = maxf(float(entry_row - y - gap), -4.0)
				gap += 1
	if not offsets.is_empty():
		_frame(frames, "refill", {"offsets": offsets})

func objective_met(state := {}) -> bool:
	var current: Dictionary = snapshot() if state.is_empty() else state
	var goal: Dictionary = level.get("goal", {"type": "score", "count": 300})
	match str(goal.type):
		"collect": return current.collected[int(goal.color)] >= int(goal.count)
		"palette":
			for target in goal.targets:
				if current.collected[int(target.color)] < int(target.count):
					return false
			return true
		"jelly": return not _has_obstacle(current.jelly)
		"blocks": return not _has_obstacle(current.blocks)
		"mixed":
			return not _has_obstacle(current.blocks) and not _has_obstacle(current.jelly) and current.collected[int(goal.color)] >= int(goal.count)
	return current.score >= int(goal.count)

func _has_obstacle(layer: PackedInt32Array) -> bool:
	for cell in layer:
		if cell > 0:
			return true
	return false

func _finish(frames: Array) -> void:
	if objective_met():
		phase = Phase.COMPLETE
	elif moves <= 0:
		phase = Phase.FAILED
	else:
		phase = Phase.IDLE
		if legal_moves(true).is_empty():
			_reshuffle(frames)

func _reshuffle(frames: Array) -> void:
	var indices: Array[int] = []
	var pieces: Array[int] = []
	for index in grid.size():
		if selectable(index):
			indices.append(index)
			pieces.append(grid[index])
	for attempt in range(48):
		for index in range(pieces.size() - 1, 0, -1):
			var other := random.randi_range(0, index)
			var value := pieces[index]
			pieces[index] = pieces[other]
			pieces[other] = value
		for index in indices.size():
			grid[indices[index]] = pieces[index]
		if matches().is_empty() and not legal_moves(true).is_empty():
			_frame(frames, "shuffle")
			return
	_make_playable()
	_frame(frames, "shuffle")

func _resolve(frames: Array, runs: Array, preferred := [], combo := {}, activated := {}) -> void:
	var depth := 1
	while not runs.is_empty() or not combo.is_empty():
		var plan := _plan(runs, preferred)
		plan.hits.merge(combo)
		_clear(plan.hits, plan.created, activated, depth, frames)
		_fall(frames)
		phase = Phase.CASCADE
		runs = matches()
		preferred = []
		combo = {}
		activated = {}
		depth += 1
		if depth > MAX_CASCADES and not runs.is_empty():
			_reshuffle(frames)
			break
	_finish(frames)

func swap(a: int, b: int) -> Dictionary:
	var frames: Array = []
	if phase != Phase.IDLE or not adjacent(a, b) or not selectable(a) or not selectable(b):
		return {"valid": false, "frames": frames}
	var combo := _special_pair(a, b)
	phase = Phase.SWAPPING
	_swap(a, b)
	_frame(frames, "swap", {"origins": {a: b, b: a}})
	phase = Phase.MATCH_CHECK
	var runs := matches()
	if not combo and runs.is_empty():
		_swap(a, b)
		_frame(frames, "swap", {"origins": {a: b, b: a}})
		phase = Phase.IDLE
		return {"valid": false, "frames": frames}
	moves -= 1
	if combo:
		_resolve(frames, runs, [b, a], _combo(a, b), {a: true, b: true})
	else:
		_resolve(frames, runs, [b, a])
	return {"valid": true, "frames": frames}

func boost(kind: String, index := -1) -> Dictionary:
	var frames: Array = []
	if phase != Phase.IDLE:
		return {"valid": false, "frames": frames}
	match kind:
		"moves":
			moves += 5
			_frame(frames, "boost")
		"shuffle":
			_reshuffle(frames)
		"hammer", "color":
			if index < 0 or index >= grid.size():
				return {"valid": false, "frames": frames}
			if kind == "color" and grid[index] == EMPTY:
				return {"valid": false, "frames": frames}
			var hits := {index: true}
			if kind == "color":
				_color_hits(color(grid[index]), hits)
			_resolve(frames, [], [], hits)
		_:
			return {"valid": false, "frames": frames}
	return {"valid": true, "frames": frames}
