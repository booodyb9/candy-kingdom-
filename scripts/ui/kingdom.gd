extends Control

const Board = preload("res://scripts/board/board.gd")
const Profile = preload("res://scripts/save/profile.gd")
const Art = preload("res://assets/candies/candy_art.gd")
const BoardView = preload("res://scripts/ui/board_view.gd")
const Sound = preload("res://assets/sounds/synth.gd")

var levels: Array
var profile
var audio
var body: VBoxContainer
var game
var view
var moves_label: Label
var score_label: Label
var goal_label: Label
var message: Label
var top_label: Label
var booster_buttons := {}
var screen := "home"
var level_id := 1
var resolved := false
var busy := false
var boost_target := ""
var refresh_clock := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	levels = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/kingdom.json"))
	profile = Profile.new()
	audio = Sound.new()
	add_child(audio)
	rng.randomize()
	Art.prepare()
	_apply_settings()
	show_home()

func _process(delta: float) -> void:
	refresh_clock += delta
	if refresh_clock >= 1.0:
		refresh_clock = 0.0
		if profile.refresh():
			profile.save()
		if is_instance_valid(top_label):
			top_label.text = _counters()

func _draw() -> void:
	Art.landscape(self, Rect2(Vector2.ZERO, size), (level_id - 1) / 10)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and not busy and is_instance_valid(body):
		if screen == "home":
			get_tree().quit()
		else:
			show_home()

func word(ar: String, en: String) -> String:
	return ar if profile.data.language == "ar" else en

func _apply_settings() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if profile.data.language == "ar" else Control.LAYOUT_DIRECTION_LTR
	audio.levels(float(profile.data.sound), float(profile.data.music))
	Engine.max_fps = 30 if profile.data.economy else 60

func _skin(fill: Color, edge: Color, radius := 15) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = fill
	skin.border_color = edge
	skin.set_corner_radius_all(radius)
	skin.set_border_width_all(2)
	skin.shadow_color = Color(0.16, 0.05, 0.23, 0.38)
	skin.shadow_size = 3
	skin.content_margin_left = 12
	skin.content_margin_right = 12
	skin.content_margin_top = 6
	skin.content_margin_bottom = 6
	return skin

func _button(parent: Node, caption: String, call: Callable, fill := Color("#7d398d"), minimum := 47) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = minimum
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 19)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tone := fill
		match state:
			"hover": tone = fill.lightened(0.12)
			"pressed": tone = fill.darkened(0.15)
			"disabled": tone = Color("#4a405d")
		button.add_theme_stylebox_override(state, _skin(tone, Color("#e9a6d4") if state != "disabled" else Color("#777087")))
	button.add_theme_stylebox_override("focus", _skin(Color(0, 0, 0, 0), Color("#fff1ad")))
	button.pressed.connect(func() -> void:
		audio.play("button")
		call.call())
	parent.add_child(button)
	return button

func _label(parent: Node, caption: String, font_size := 20, tint := Color("#fff6ff")) -> Label:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color("#2f154c"))
	label.add_theme_constant_override("outline_size", 5 if font_size > 22 else 3)
	parent.add_child(label)
	return label

func _row(parent: Node, separation := 7) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row

func _spacer(parent: Node) -> void:
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(filler)

func _card(parent: Node, tint := Color("#532c74")) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _skin(tint, Color("#df9fb7")))
	parent.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	card.add_child(inner)
	return inner

func _counters() -> String:
	return word("♥  %d / 5     •     عملات  %d", "♥  %d / 5     •     Coins  %d") % [profile.data.lives, profile.data.coins]

func _layout(next_screen: String) -> void:
	screen = next_screen
	for child in get_children():
		if child != audio:
			remove_child(child)
			child.queue_free()
	var margins := MarginContainer.new()
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := Rect2i()
	if OS.has_feature("mobile"):
		insets = DisplayServer.get_display_safe_area()
	var window_size := Vector2(get_window().size)
	var factor := size / window_size
	var left := int(maxf(0, insets.position.x * factor.x))
	var top := int(maxf(0, insets.position.y * factor.y))
	var right := 0
	var bottom := 0
	if insets.has_area():
		right = int(maxf(0, (window_size.x - insets.end.x) * factor.x))
		bottom = int(maxf(0, (window_size.y - insets.end.y) * factor.y))
	for entry in [["left", left + 12], ["right", right + 12], ["top", top + 10], ["bottom", bottom + 9]]:
		margins.add_theme_constant_override("margin_" + entry[0], entry[1])
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margins.add_child(body)
	var toolbar := _row(body)
	top_label = _label(toolbar, _counters(), 18)
	top_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if next_screen != "settings":
		var settings := _button(toolbar, "⚙", show_settings, Color("#673883"), 42)
		settings.size_flags_horizontal = Control.SIZE_FILL
		settings.custom_minimum_size.x = 48
	if profile.data.motion:
		body.modulate.a = 0.35
		create_tween().tween_property(body, "modulate:a", 1.0, 0.22)
	queue_redraw()

func show_home() -> void:
	if busy:
		return
	_layout("home")
	_spacer(body)
	var logo := _card(body, Color("#653177"))
	_label(logo, "♛", 48, Color("#ffd774"))
	var heading := _label(logo, word("مملكة الحلوى", "Sweet Kingdom"), 48, Color("#ffe289"))
	_label(logo, word("Sweet Kingdom", "مملكة الحلوى"), 20, Color("#ffcfe7"))
	if profile.data.motion:
		heading.modulate.a = 0.35
		create_tween().tween_property(heading, "modulate:a", 1.0, 0.55)
	_spacer(body)
	_button(body, word("العب الآن", "Play now"), func() -> void: start_level(int(profile.data.unlocked)), Color("#348043"), 69)
	_button(body, word("خريطة المراحل", "Level map"), show_map, Color("#863c95"), 55)
	var actions := _row(body)
	_button(actions, word("الصوت", "Sound"), func() -> void:
		_toggle("sound")
		show_home())
	_button(actions, word("الموسيقى", "Music"), func() -> void:
		_toggle("music")
		show_home())
	_button(actions, word("English", "العربية"), func() -> void:
		_language()
		show_home())
	var stars := 0
	for result in profile.data.results.values():
		stars += int(result.stars)
	_label(_card(body), word("تقدمك  ★  %d / 150", "Progress  ★  %d / 150") % stars, 21)
	if profile.notice != "":
		var notice := word("تعذرت كتابة الحفظ.", "Saving failed.")
		if profile.notice == "recovered":
			notice = word("تم استرجاع آخر نسخة حفظ سليمة.", "Recovered the last valid save.")
		elif profile.notice == "damaged":
			notice = word("ملفات الحفظ تالفة. ابدأ ملفًا جديدًا؟", "Save files are damaged. Start a new profile?")
		_button(body, notice, func() -> void:
			profile.acknowledge_damage()
			show_home(), Color("#883854"))
	elif int(profile.data.lives) == 0:
		_label(_card(body), word("حياة جديدة خلال ٢٠ دقيقة كحد أقصى", "Next life returns within 20 minutes"), 16)

func show_map() -> void:
	if busy:
		return
	_layout("map")
	_label(body, word("خريطة المملكة", "Kingdom map"), 34, Color("#ffe592"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var path := VBoxContainer.new()
	path.add_theme_constant_override("separation", 10)
	path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(path)
	var active: Button
	for index in range(49, -1, -1):
		var id := index + 1
		if id % 10 == 0:
			var names_ar := ["وادي السكر", "جسور الكراميل", "غابة التفاح", "بحيرة التوت", "القصر الذهبي"]
			var names_en := ["Sugar Valley", "Caramel Bridges", "Apple Grove", "Berry Lake", "Golden Palace"]
			_label(_card(path), word(names_ar[index / 10], names_en[index / 10]), 20)
		var node_row := _row(path)
		var indent := Control.new()
		indent.custom_minimum_size.x = 36 + (1.0 + sin(id * 0.76)) * 100.0
		node_row.add_child(indent)
		var stars := int(profile.data.results.get(str(id), {}).get("stars", 0))
		var locked := id > int(profile.data.unlocked)
		var badge := "  " + "★".repeat(stars) if stars > 0 else ("  ×" if locked else "")
		var node := _button(node_row, str(id) + badge, func() -> void: start_level(id),
			Color("#9b4c37") if id == int(profile.data.unlocked) else Color("#315da2"), 50)
		node.size_flags_horizontal = Control.SIZE_FILL
		node.custom_minimum_size.x = 108
		node.disabled = locked
		if id == int(profile.data.unlocked):
			active = node
	_button(body, word("الرئيسية", "Home"), show_home)
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(active):
		scroll.ensure_control_visible(active)

func _language() -> void:
	profile.data.language = "en" if profile.data.language == "ar" else "ar"
	_apply_settings()
	profile.save()

func _toggle(key: String) -> void:
	profile.data[key] = 0.0 if float(profile.data[key]) > 0.0 else 0.65
	_apply_settings()
	profile.save()

func show_settings() -> void:
	if busy:
		return
	var previous := screen
	_layout("settings")
	_spacer(body)
	var panel := _card(body)
	_label(panel, word("الإعدادات", "Settings"), 32, Color("#ffde95"))
	_button(panel, word("اللغة · English", "Language · العربية"), func() -> void:
		_language()
		show_home())
	for entry in [["sound", word("المؤثرات الصوتية", "Sound effects")], ["music", word("الموسيقى", "Music")]]:
		var key: String = entry[0]
		_label(panel, entry[1], 17)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size.y = 35
		slider.value = profile.data[key]
		slider.value_changed.connect(func(value: float) -> void:
			profile.data[key] = value
			_apply_settings())
		slider.drag_ended.connect(func(_changed: bool) -> void: profile.save())
		slider.focus_exited.connect(func() -> void: profile.save())
		panel.add_child(slider)
	var motion := CheckButton.new()
	motion.text = word("تقليل الحركة", "Reduce motion")
	motion.button_pressed = not profile.data.motion
	panel.add_child(motion)
	motion.toggled.connect(func(value: bool) -> void:
		profile.data.motion = not value
		profile.save())
	var performance := CheckButton.new()
	performance.text = word("توفير الطاقة · ٣٠ إطارًا", "Battery saver · 30 FPS")
	performance.button_pressed = profile.data.economy
	panel.add_child(performance)
	performance.toggled.connect(func(value: bool) -> void:
		profile.data.economy = value
		_apply_settings()
		profile.save())
	_button(panel, word("رجوع", "Back"), func() -> void:
		profile.save()
		if previous == "game":
			_show_game()
		elif previous == "map":
			show_map()
		else:
			show_home())
	_spacer(body)

func start_level(id: int, seed_value := -1) -> void:
	if busy or id < 1 or id > int(profile.data.unlocked):
		return
	if int(profile.data.lives) <= 0:
		show_home()
		return
	level_id = id
	game = Board.new(levels[id - 1], rng.randi() if seed_value < 0 else seed_value)
	resolved = false
	boost_target = ""
	_show_game()

func _show_game() -> void:
	_layout("game")
	var overview := _card(body)
	_label(overview, word("المرحلة %d", "Level %d") % level_id, 26, Color("#ffde87"))
	goal_label = _label(overview, "", 17)
	var totals := _row(overview)
	moves_label = _label(totals, "", 19)
	moves_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label = _label(totals, "", 19)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message = _label(body, "", 16, Color("#ffe7a3"))
	view = BoardView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size.y = 225
	view.engine = game
	view.display = game.snapshot()
	view.animate = profile.data.motion and not profile.data.economy
	body.add_child(view)
	view.cell_tapped.connect(_tap)
	view.swipe_made.connect(_swap)
	var tools := _row(body, 5)
	booster_buttons = {}
	for kind in ["hammer", "moves", "shuffle", "color"]:
		var booster := _button(tools, "", func() -> void: _choose_boost(kind), Color("#753c91"), 54)
		booster.add_theme_font_size_override("font_size", 14)
		booster_buttons[kind] = booster
	var nav := _row(body)
	_button(nav, word("الخريطة", "Map"), show_map, Color("#56417c"), 39)
	_button(nav, word("إعادة", "Restart"), func() -> void: start_level(level_id), Color("#56417c"), 39)
	_update(game.snapshot())
	if resolved:
		_result(false)
	elif level_id <= 5:
		message.text = word("حرّك قطعة أو اختار قطعتين متجاورتين", "Swipe a candy or tap two neighbors")

func _sum(layer: PackedInt32Array) -> int:
	var count := 0
	for hp in layer:
		count += hp
	return count

func _update(state: Dictionary) -> void:
	var goal: Dictionary = game.level.goal
	var target := ""
	match str(goal.type):
		"collect", "mixed":
			var ar := ["فراولة", "بلّور", "تفاح", "ليمون", "عنب", "برتقال"]
			var en := ["Strawberry", "Crystal", "Apple", "Lemon", "Grape", "Orange"]
			var color_index := int(goal.color)
			target = "%s %d/%d" % [word(ar[color_index], en[color_index]), state.collected[color_index], goal.count]
			if str(goal.type) == "mixed":
				target += word("  •  هلام %d  •  قطع %d", "  •  Jelly %d  •  Blocks %d") % [_sum(state.jelly), _sum(state.blocks)]
		"jelly": target = word("الهلام المتبقي %d", "Jelly layers left %d") % _sum(state.jelly)
		"blocks": target = word("القطع المتبقية %d", "Block hits left %d") % _sum(state.blocks)
		_: target = word("الهدف %d نقطة", "Target %d points") % goal.count
	goal_label.text = target
	moves_label.text = word("الحركات %d", "Moves %d") % state.moves
	score_label.text = word("النقاط %d", "Score %d") % state.score
	var captions := {"hammer": word("مطرقة", "Hammer"), "moves": "+5", "shuffle": word("خلط", "Shuffle"), "color": word("لون", "Color")}
	for kind in booster_buttons:
		var count := int(profile.data.stock.get(kind, 0))
		var label: String = captions[kind]
		booster_buttons[kind].text = label + "\n" + (str(count) if count > 0 else "● " + str(Profile.COST[kind]))
		booster_buttons[kind].disabled = busy or resolved or not profile.can_spend(kind)

func _tap(index: int) -> void:
	if busy or resolved:
		return
	if boost_target != "":
		_use_boost(boost_target, index)
		return
	if not game.selectable(index):
		return
	if game.adjacent(view.selected, index):
		_swap(view.selected, index)
		return
	view.selected = index if view.selected != index else -1
	view.queue_redraw()
	audio.play("select")

func _swap(a: int, b: int) -> void:
	if busy or resolved:
		return
	if boost_target != "":
		_use_boost(boost_target, b)
		return
	view.selected = -1
	var turn: Dictionary = game.swap(a, b)
	await _animate(turn.frames)
	if not turn.valid and not turn.frames.is_empty():
		message.text = word("جرّب تبديلًا يعمل تطابق", "Try a swap that makes a match")

func _choose_boost(kind: String) -> void:
	if busy or resolved or not profile.can_spend(kind):
		return
	if kind in ["hammer", "color"]:
		boost_target = "" if boost_target == kind else kind
		message.text = word("اختار قطعة", "Choose a tile") if boost_target != "" else ""
	else:
		_use_boost(kind)

func _use_boost(kind: String, index := -1) -> void:
	if busy or resolved or not profile.can_spend(kind):
		return
	var action: Dictionary = game.boost(kind, index)
	if not action.valid:
		return
	profile.spend(kind)
	boost_target = ""
	view.selected = -1
	await _animate(action.frames)

func _animate(frames: Array) -> void:
	if frames.is_empty():
		return
	busy = true
	view.busy = true
	message.text = ""
	_update(view.display)
	for animation in frames:
		view.frame = animation
		view.display = animation.board
		view.progress = 0.0
		var kind: String = animation.kind
		if kind == "clear":
			var depth := int(animation.data.combo)
			if depth > 1:
				message.text = word("سلسلة ×%d", "Combo ×%d") % mini(5, depth)
			audio.play("power" if not animation.data.powers.is_empty() else ("combo" if depth > 1 else "match"))
		elif kind == "swap":
			audio.play("swap")
		elif kind == "shuffle":
			message.text = word("تم خلط اللوحة", "Board shuffled")
		_update(view.display)
		view.queue_redraw()
		if profile.data.motion:
			var tween := create_tween()
			tween.tween_method(func(value: float) -> void:
				view.progress = value
				view.queue_redraw(), 0.0, 1.0, 0.12 if kind == "swap" else 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await tween.finished
		view.progress = 1.0
	view.frame = {}
	view.display = game.snapshot()
	view.queue_redraw()
	view.busy = false
	busy = false
	_update(view.display)
	if game.phase in [Board.Phase.COMPLETE, Board.Phase.FAILED]:
		_result(true)

func _result(record: bool) -> void:
	var success: bool = game.phase == Board.Phase.COMPLETE
	resolved = true
	view.busy = true
	var result := {}
	if record:
		if success:
			result = profile.win(game.level, game.score)
		else:
			profile.lose_life()
		audio.play("win" if success else "fail")
	elif success:
		result = profile.data.results.get(str(level_id), {})
	_update(game.snapshot())
	var text := word("المرحلة اكتملت!", "Level complete!") if success else word("انتهت الحركات", "Out of moves")
	if success:
		text += "  " + "★".repeat(int(result.get("stars", 1)))
		if result.has("coins"):
			text += "   +%d" % result.coins
	message.text = text
	if success and level_id < 50:
		_button(body, word("المرحلة التالية", "Next level"), func() -> void: start_level(level_id + 1), Color("#358044"), 42)
	if success and profile.data.motion:
		message.modulate.a = 0.25
		create_tween().tween_property(message, "modulate:a", 1.0, 0.45)
