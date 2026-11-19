extends SceneTree

const Board = preload("res://scripts/board/board.gd")
const Profile = preload("res://scripts/save/profile.gd")
var failures := 0
var cases := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	cases += 1
	if not condition:
		failures += 1
		printerr("FAIL " + label)

func fixture(seed_value := 19):
	return Board.new({"width": 6, "height": 6, "moves": 22, "colors": 5, "goal": {"type": "score", "count": 99999}}, seed_value)

func _run() -> void:
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/kingdom.json"))
	check(levels.size() == 50, "50 level definitions")
	var no_wins: Array[int] = []
	for level in levels:
		for seed_value in [11, 29, 57]:
			var initial = Board.new(level, seed_value)
			check(initial.matches().is_empty() and not initial.legal_moves(true).is_empty(), "playable initial board %s seed %s" % [level.id, seed_value])
		var won := false
		for sample in 4:
			if _simulate(level, int(level.id) * 409 + sample):
				won = true
				break
		if not won:
			no_wins.append(int(level.id))
	print("Balance smoke simulation (four deterministic seeds per level). No sampled win: ", no_wins)
	check(no_wins.size() < 10, "balance smoke at least 41 of 50 levels have sampled wins")
	var board = fixture()
	var copy = fixture()
	check(board.grid == copy.grid, "seed reproducibility")
	var original: PackedInt32Array = board.grid.duplicate()
	var illegal := Vector2i(-1, -1)
	var legal: Array = board.legal_moves()
	for index in board.grid.size():
		if board.adjacent(index, index + 1) and not legal.has(Vector2i(index, index + 1)):
			illegal = Vector2i(index, index + 1)
			break
	check(illegal.x >= 0, "invalid candidate exists")
	var invalid: Dictionary = board.swap(illegal.x, illegal.y)
	check(not invalid.valid and invalid.frames.size() == 2 and original == board.grid and board.moves == 22, "invalid swap rolls back without consuming moves")
	var move: Vector2i = legal[0]
	var valid: Dictionary = board.swap(move.x, move.y)
	check(valid.valid and board.moves == 21 and board.score > 0, "valid swap awards points and consumes a move")
	check(board.matches().is_empty() and not board.grid.has(-1), "cascade ends fully settled")
	check(valid.frames.any(func(frame: Dictionary) -> bool: return frame.kind == "refill"), "refill frame")
	var saw_combo := false
	for seed_value in range(1, 90):
		var combo_board = fixture(seed_value)
		var pair: Vector2i = combo_board.legal_moves(true)[0]
		var frames: Array = combo_board.swap(pair.x, pair.y).frames
		var multiplier := 0
		var expected := 0
		for frame in frames:
			if frame.kind == "clear":
				multiplier = int(frame.data.combo)
				expected += (frame.data.cells.size() * 10 + frame.data.damaged.size() * 15) * mini(multiplier, 5)
		if multiplier >= 2:
			saw_combo = true
			check(expected == combo_board.score, "cascade multiplier scoring")
			break
	check(saw_combo, "seed set exercises a cascade")

	board.grid.fill(Board.EMPTY)
	for index in [0, 1, 2, 3]:
		board.grid[index] = 1
	check(board.matches().size() == 1 and board.matches()[0].power == Board.Power.ROW, "horizontal run")
	var marks: Dictionary = board._plan(board.matches(), [2])
	check(Board.power(marks.created[2]) == Board.Power.ROW, "match four creates rocket")
	board.grid[4] = 1
	marks = board._plan(board.matches(), [2])
	check(Board.power(marks.created[2]) == Board.Power.RAINBOW, "match five creates rainbow")
	board.grid.fill(Board.EMPTY)
	for index in [2, 7, 8, 9, 14]:
		board.grid[index] = 2
	check(board.matches().size() == 2 and board.matches()[1].power == Board.Power.COLUMN, "vertical run")
	marks = board._plan(board.matches(), [8])
	check(Board.power(marks.created[8]) == Board.Power.BOMB, "intersection creates bomb")
	board.grid.fill(Board.EMPTY)
	board.grid[0] = 3
	var fall_frames: Array = []
	board._fall(fall_frames)
	check(board.grid[30] == 3 and fall_frames[0].data.origins[30] == 0, "gravity")
	check(not board.grid.has(Board.EMPTY), "refill")
	for index in board.grid.size():
		board.grid[index] = (index % board.width + (index / board.width) * 2) % 5
	check(board.legal_moves().is_empty(), "deadlock detection")
	check(board.boost("shuffle").valid and board.matches().is_empty() and not board.legal_moves().is_empty(), "shuffle produces legal move")
	var before_moves: int = board.moves
	check(board.boost("moves").valid and board.moves == before_moves + 5, "extra moves booster")
	check(board.boost("hammer", 0).valid and board.score > 0, "hammer booster")
	check(board.boost("color", 0).valid, "color booster")
	var combo = fixture()
	combo.grid[0] = 1 + Board.Power.RAINBOW * Board.RADIX
	combo.grid[1] = 2 + Board.Power.RAINBOW * Board.RADIX
	var explosion: Dictionary = combo.swap(0, 1)
	check(explosion.valid and explosion.frames[1].data.cells.size() == 36, "rainbow-rainbow clears full board")
	var goal = Board.new({"moves": 1, "goal": {"type": "score", "count": 1}}, 43)
	move = goal.legal_moves(true)[0]
	goal.swap(move.x, move.y)
	check(goal.phase == Board.Phase.COMPLETE, "objective on last move wins")
	var failed = fixture()
	failed.moves = 1
	move = failed.legal_moves(true)[0]
	failed.swap(move.x, move.y)
	check(failed.phase == Board.Phase.FAILED, "last move fails when goal remains")
	var tiles = Board.new({"tiles": [[1, 1, "block", 2], [0, 0, "jelly", 2], [3, 3, "lock", 2]],
		"goal": {"type": "blocks"}}, 11)
	tiles.boost("hammer", 9)
	check(tiles.blocks[9] == 1 and not tiles.objective_met(), "multi-hit block takes damage")
	tiles.boost("hammer", 9)
	check(tiles.blocks[9] == 0 and tiles.phase == Board.Phase.COMPLETE, "block objective completes")
	var path := "user://tests-%s" % Time.get_ticks_usec()
	var profile = Profile.new(path)
	profile.lose_life()
	var refill_at: int = profile.data.refill_at
	check(not profile.refresh(refill_at - 1), "life does not refill early")
	check(profile.refresh(refill_at) and profile.data.lives == 5, "life refills once")
	profile.win(levels[0], 900)
	profile.spend("hammer")
	var loaded = Profile.new(path)
	check(loaded.data.unlocked == 2 and loaded.data.results["1"].score == 900 and loaded.data.stock.hammer == 2, "saved unlock score and inventory")
	var current: String = path.path_join("profile-%d.json" % (loaded.generation % 2))
	var corrupt := FileAccess.open(current, FileAccess.WRITE)
	corrupt.store_string("corrupted")
	corrupt = null
	var recovered = Profile.new(path)
	check(recovered.notice == "recovered" and recovered.data.unlocked == 2, "save journal recovery")

	var packed: PackedScene = load("res://scenes/kingdom.tscn")
	var ui = packed.instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	check(ui.screen == "home" and ui.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Arabic RTL startup layout")
	ui.profile.data.motion = false
	ui.start_level(1, 210)
	await process_frame
	await process_frame
	check(ui.screen == "game" and ui.view.square() >= 30, "gameplay board fits portrait viewport")
	move = ui.game.legal_moves(true)[0]
	var begin := InputEventMouseButton.new()
	begin.button_index = MOUSE_BUTTON_LEFT
	begin.pressed = true
	begin.position = ui.view.center(move.x)
	var end := InputEventMouseButton.new()
	end.button_index = MOUSE_BUTTON_LEFT
	end.pressed = false
	end.position = ui.view.center(move.y)
	var before: int = ui.game.moves
	ui.view._gui_input(begin)
	ui.view._gui_input(end)
	check(ui.game.moves == before - 1 and not ui.busy, "swipe resolves through gameplay UI")
	ui.start_level(1, 210)
	check(ui.game.moves == int(levels[0].moves) and ui.game.score == 0, "game restart")
	ui._language()
	check(ui.layout_direction == Control.LAYOUT_DIRECTION_LTR, "English LTR switch")
	ui.queue_free()
	await process_frame
	print("Sweet Kingdom checks: %d passed, %d failed" % [cases - failures, failures])
	quit(0 if failures == 0 else 1)

func _simulate(level: Dictionary, seed_value: int) -> bool:
	var board = Board.new(level, seed_value)
	while board.phase == Board.Phase.IDLE:
		var moves: Array = board.legal_moves()
		if moves.is_empty():
			break
		var best: Vector2i = moves[0]
		var value := -INF
		for move in moves:
			board._swap(move.x, move.y)
			var runs: Array = board.matches()
			var ranking := 0.0
			for run in runs:
				ranking += run.cells.size()
				for cell in run.cells:
					ranking += 4.0 * board.jelly[cell]
					var kind := Board.color(board.grid[cell])
					if kind == int(level.goal.get("color", -1)):
						ranking += 1.6
					for neighbor in [cell - board.width, cell + board.width, cell - 1, cell + 1]:
						if board.adjacent(cell, neighbor):
							ranking += 2.5 * board.blocks[neighbor]
			if board._special_pair(move.x, move.y):
				ranking += 5.0
			board._swap(move.x, move.y)
			if ranking > value:
				best = move
				value = ranking
		board.swap(best.x, best.y)
	return board.phase == Board.Phase.COMPLETE
