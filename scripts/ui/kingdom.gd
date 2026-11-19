extends Control

const Board = preload("res://scripts/board/board.gd")
const Profile = preload("res://scripts/save/profile.gd")
const Art = preload("res://assets/candies/candy_art.gd")
const BoardView = preload("res://scripts/ui/board_view.gd")
const Sound = preload("res://assets/sounds/synth.gd")
const Glaze = preload("res://scripts/ui/glaze.gd")
const Glyph = preload("res://scripts/ui/glyph.gd")
const Trail = preload("res://scripts/ui/trail.gd")
const FONT = preload("res://assets/fonts/Tajawal-ExtraBold.ttf")
const SCENERY = preload("res://assets/backgrounds/candy-valley.png")
const HOME_ART = preload("res://assets/backgrounds/kingdom-home.png")
const MAP_ART = preload("res://assets/backgrounds/sugar-river.png")
const CREST = preload("res://assets/backgrounds/logo-crest.png")
const BERRY := Color("#bc247d")
const PLUM := Color("#8334ab")
const DENIM := Color("#1769b8")
const LIME := Color("#66bd0c")
const CHERRY := Color("#cd384e")

var levels: Array
var profile
var audio
var body: VBoxContainer
var game
var view
var moves_label: Label
var score_label: Label
var goal_values: Array[Label] = []
var star_line: Label
var goal_specs: Array = []
var point_bar: ProgressBar
var message: Label
var live_count: Label
var coin_count: Label
var booster_badges := {}
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
		_refresh_wallet()

func _draw() -> void:
	var art: Texture2D = HOME_ART if screen == "home" else (MAP_ART if screen == "map" else SCENERY)
	var factor := maxf(size.x / art.get_width(), size.y / art.get_height())
	var extent := art.get_size() * factor
	draw_texture_rect(art, Rect2((size - extent) * Vector2(0.34 if screen == "home" else 0.5, 0.5), extent), false)

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
	skin.shadow_size = 4
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
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_outline_color", Color("#48223d"))
	button.add_theme_constant_override("outline_size", 4)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tone := fill
		match state:
			"hover": tone = fill.lightened(0.12)
			"pressed": tone = fill.darkened(0.15)
			"disabled": tone = Color("#4a405d")
		button.add_theme_stylebox_override(state, Glaze.gloss(tone))
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
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color("#2f154c"))
	label.add_theme_constant_override("outline_size", 0 if tint == Glaze.INK else (6 if font_size > 30 else 3))
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
	card.add_theme_stylebox_override("panel", Glaze.gloss(tint))
	parent.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	card.add_child(inner)
	return inner

func _refresh_wallet() -> void:
	if is_instance_valid(live_count):
		live_count.text = word("%d / ٥", "%d / 5") % profile.data.lives
	if is_instance_valid(coin_count):
		coin_count.text = str(profile.data.coins)

func _icon(parent: Control, kind: String, dimension := 38, candy := -1) -> Control:
	var mark := Glyph.new()
	mark.kind = kind
	mark.piece = candy
	mark.custom_minimum_size = Vector2.ONE * dimension
	parent.add_child(mark)
	return mark

func _mark(parent: Control, kind: String, extent := 0.65, y := 0.45) -> void:
	var mark := _icon(parent, kind, 0)
	mark.anchor_left = 0.5 - extent / 2
	mark.anchor_right = 0.5 + extent / 2
	mark.anchor_top = y - extent / 2
	mark.anchor_bottom = y + extent / 2

func _wallet(parent: Node, kind: String, color: Color) -> Label:
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.custom_minimum_size.y = 45
	shell.add_theme_stylebox_override("panel", Glaze.gloss(color, 23.0))
	parent.add_child(shell)
	var inside := _row(shell, 5)
	inside.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_icon(inside, kind, 31)
	var label := _label(inside, "", 23)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _action(parent: Node, caption: String, callback: Callable, color: Color, height: int, width: int) -> Button:
	var button := _button(parent, caption, callback, color, height)
	button.custom_minimum_size.x = width
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button

func _logo(parent: Node, compact: bool) -> void:
	var plaque := Control.new()
	plaque.custom_minimum_size = Vector2(300, 94) if compact else Vector2(380, 212)
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(plaque)
	var crest := TextureRect.new()
	crest.texture = CREST
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_SCALE
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(crest)
	crest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crest.offset_top = -4 if compact else -22
	crest.offset_bottom = 8 if compact else 4
	var headline := _label(plaque, word("مملكة الحلوى" if compact else "مملكة\nالحلوى", "Sweet Kingdom" if compact else "Sweet\nKingdom"), 41 if compact else 66, Glaze.GOLD)
	headline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	headline.offset_top = 21 if compact else 42
	headline.offset_bottom = -6 if compact else -23
	headline.add_theme_constant_override("line_spacing", -14)
	headline.add_theme_color_override("font_outline_color", Color("#621036"))
	headline.add_theme_constant_override("outline_size", 8)
	var caption := _label(plaque, word("Sweet Kingdom", "مملكة الحلوى"), 15 if compact else 23)
	caption.anchor_left = 0.20
	caption.anchor_right = 0.80
	caption.anchor_top = 0.82 if compact else 0.84
	caption.anchor_bottom = 0.99 if compact else 0.94
	caption.offset_bottom = 4 if compact else 0
	if profile.data.motion:
		plaque.modulate.a = 0.45
		create_tween().tween_property(plaque, "modulate:a", 1.0, 0.30)

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
	toolbar.layout_direction = Control.LAYOUT_DIRECTION_LTR
	live_count = _wallet(toolbar, "heart", Color("#932b68"))
	coin_count = _wallet(toolbar, "coin", Color("#81286e"))
	_refresh_wallet()
	if next_screen != "settings":
		var settings := _action(toolbar, "⚙", show_settings, DENIM, 45, 50)
		settings.add_theme_font_size_override("font_size", 25)
		settings.tooltip_text = word("الإعدادات", "Settings")

	if profile.data.motion:
		body.modulate.a = 0.35
		create_tween().tween_property(body, "modulate:a", 1.0, 0.22)
	queue_redraw()

func show_home() -> void:
	if busy:
		return
	_layout("home")
	_spacer(body)
	_logo(body, false)
	_spacer(body)
	var play := _action(body, word("العب الآن", "Play now"), func() -> void: start_level(int(profile.data.unlocked)), LIME, 85, 300)
	play.add_theme_font_size_override("font_size", 38)
	var map := _action(body, word("المراحل", "Level map"), show_map, BERRY, 64, 242)
	map.add_theme_font_size_override("font_size", 28)
	_spacer(body)
	var actions := _row(body, 6)
	_button(actions, word("الإنجازات", "Awards"), show_achievements, PLUM, 56)
	_button(actions, word("المكافآت", "Rewards"), show_rewards, PLUM, 56)
	_button(actions, word("الصوت", "Sound"), func() -> void:
		_toggle("sound")
		show_home(), PLUM if float(profile.data.sound) > 0 else Color("#915283"), 56)
	_button(actions, word("الموسيقى", "Music"), func() -> void:
		_toggle("music")
		show_home(), PLUM if float(profile.data.music) > 0 else Color("#915283"), 56)
	var stats := _row(body)
	_action(stats, word("العربية · EN", "English · عربي"), func() -> void:
		_language()
		show_home(), BERRY, 48, 116)
	var progress_card := PanelContainer.new()
	progress_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_card.add_theme_stylebox_override("panel", Glaze.gloss(Color("#9f3a70"), 21.0))
	stats.add_child(progress_card)
	_label(progress_card, word("تقدمك  ★  %d / 150", "Progress  ★  %d / 150") % _star_count(), 22)
	if profile.notice != "":
		var notice := word("تعذرت كتابة الحفظ.", "Saving failed.")
		if profile.notice == "recovered":
			notice = word("تم استرجاع آخر نسخة حفظ سليمة.", "Recovered the last valid save.")
		elif profile.notice == "damaged":
			notice = word("ملفات الحفظ تالفة. ابدأ ملفًا جديدًا؟", "Save files are damaged. Start a new profile?")
		_button(body, notice, func() -> void:
			profile.acknowledge_damage()
			show_home(), CHERRY)
	elif int(profile.data.lives) == 0:
		_label(_card(body), word("حياة جديدة خلال ٢٠ دقيقة كحد أقصى", "Next life returns within 20 minutes"), 16)

func _star_count() -> int:
	var stars := 0
	for result in profile.data.results.values():
		stars += int(result.stars)
	return stars

func show_achievements() -> void:
	_layout("achievements")
	_spacer(body)
	var card := _card(body, BERRY)
	_label(card, word("إنجازاتي", "Achievements"), 35, Glaze.GOLD)
	for milestone in [1, 10, 25, 50]:
		var status := "✓" if profile.data.results.size() >= milestone else "◇"
		_label(card, word("%s  إكمال %d مرحلة", "%s  Complete %d levels") % [status, milestone], 22)
	_button(body, word("الرئيسية", "Home"), show_home, PLUM)
	_spacer(body)

func show_rewards() -> void:
	_layout("rewards")
	_spacer(body)
	var card := _card(body, BERRY)
	_label(card, word("مكافآتي", "Rewards"), 35, Glaze.GOLD)
	_label(card, word("★  %d نجمة", "★  %d stars") % _star_count(), 24)
	_label(card, word("%d عملة", "%d coins") % profile.data.coins, 24)
	_label(card, word("أكمل المراحل لكسب العملات والنجوم", "Complete levels to earn stars and coins"), 18)
	_button(body, word("الرئيسية", "Home"), show_home, PLUM)
	_spacer(body)

func show_map() -> void:
	if busy:
		return
	_layout("map")
	_logo(body, true)
	var holder := PanelContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_theme_stylebox_override("panel", Glaze.crumb(Color("#fac484"), Color("#fff0a9")))
	body.add_child(holder)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	holder.add_child(scroll)
	holder.clip_contents = true
	var trail := Trail.new()
	trail.scenery = MAP_ART
	trail.active = int(profile.data.unlocked)
	trail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(trail)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: trail.queue_redraw())
	for id in range(1, 51):
		var locked := id > int(profile.data.unlocked)
		var tint := BERRY if id == trail.active else DENIM
		var node := _button(trail, str(id), func() -> void: start_level(id), tint, 55)
		node.size = Vector2(59, 55)
		node.add_theme_font_size_override("font_size", 25)
		node.tooltip_text = word("المرحلة %d", "Level %d") % id
		node.disabled = locked
		var stars := int(profile.data.results.get(str(id), {}).get("stars", 0))
		if stars > 0:
			var award := _label(node, "★".repeat(stars), 17, Glaze.GOLD)
			award.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			award.offset_top = 47
			award.offset_bottom = 18
		elif locked:
			_mark(node, "lock", 0.31, 0.83)
		trail.stops.append(node)
	trail.reflow()
	var menu := _row(body)
	_button(menu, word("الرئيسية", "Home"), show_home, PLUM, 48)
	_button(menu, word("العب الآن", "Play"), func() -> void: start_level(int(profile.data.unlocked)), LIME, 48)
	_button(menu, word("مكافآتي", "Rewards"), show_rewards, PLUM, 48)
	await get_tree().process_frame
	if is_instance_valid(scroll):
		var local := trail.coordinate(trail.active)
		scroll.scroll_vertical = maxi(0, int(local.y - scroll.size.y * 0.79))

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
		elif previous == "pause":
			show_pause()
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
	_logo(body, true)
	var overview := PanelContainer.new()
	overview.add_theme_stylebox_override("panel", Glaze.gloss(Color("#ffb68c"), 23.0, 7.0))
	body.add_child(overview)
	var record := _row(overview, 7)
	record.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_tile_stat(record, word("المرحلة", "Level"), str(level_id), Glaze.GOLD)
	var goals := VBoxContainer.new()
	goals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goals.add_theme_constant_override("separation", -3)
	record.add_child(goals)
	_label(goals, word("الأهداف", "Goals"), 20, Glaze.INK)
	var trophies := _row(goals, 4)
	trophies.alignment = BoxContainer.ALIGNMENT_CENTER
	_make_goals(trophies)
	moves_label = _tile_stat(record, word("الحركات", "Moves"), "", Color.WHITE)

	var score := PanelContainer.new()
	score.custom_minimum_size.y = 33
	score.add_theme_stylebox_override("panel", Glaze.gloss(Color("#71205c"), 19.0, 5.0))
	body.add_child(score)
	var score_row := _row(score, 8)
	score_label = _label(score_row, "", 20)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	point_bar = ProgressBar.new()
	point_bar.show_percentage = false
	point_bar.custom_minimum_size = Vector2(76, 11)
	point_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	point_bar.add_theme_stylebox_override("background", Glaze.crumb(Color("#531749"), Color("#a75589"), 7))
	point_bar.add_theme_stylebox_override("fill", Glaze.crumb(Color("#ffc544"), Color("#fff29d"), 7))
	score_row.add_child(point_bar)
	star_line = _label(score_row, "", 22, Glaze.GOLD)
	star_line.custom_minimum_size.x = 77

	view = BoardView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size.y = 240
	view.engine = game
	view.display = game.snapshot()
	view.animate = profile.data.motion and not profile.data.economy
	body.add_child(view)
	view.cell_tapped.connect(_tap)
	view.swipe_made.connect(_swap)
	message = _label(body, "", 17, Color("#fff8d1"))
	message.custom_minimum_size.y = 21
	var tools := _row(body, 14)
	tools.layout_direction = Control.LAYOUT_DIRECTION_LTR
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	var pause := _orb(tools, "pause", word("إيقاف مؤقت", "Pause"), CHERRY, show_pause)
	pause.tooltip_text = word("إيقاف مؤقت", "Pause")
	booster_buttons = {}
	booster_badges = {}
	var names := {"hammer": word("مطرقة", "Hammer"), "moves": word("خمس حركات", "Extra moves"), "shuffle": word("خلط", "Shuffle"), "color": word("تفجير لون", "Color blast")}
	for kind in ["hammer", "shuffle", "moves", "color"]:
		var booster := _orb(tools, str(kind), names[kind], DENIM if kind == "shuffle" else PLUM, func() -> void: _choose_boost(kind))
		var badge := _label(booster, "", 16)
		badge.anchor_left = 0.58
		badge.anchor_right = 0.99
		badge.anchor_top = 0.66
		badge.anchor_bottom = 1.01
		badge.add_theme_color_override("font_outline_color", Color("#9b274c"))
		badge.add_theme_constant_override("outline_size", 8)
		booster_buttons[kind] = booster
		booster_badges[kind] = badge
	_update(game.snapshot())
	if resolved:
		_result(false)
	elif level_id <= 5:
		message.text = word("حرّك قطعة أو اختار قطعتين متجاورتين", "Swipe a candy or tap two neighbors")

func _tile_stat(parent: HBoxContainer, title: String, value: String, tint: Color) -> Label:
	var tile := PanelContainer.new()
	tile.custom_minimum_size.x = 85
	tile.add_theme_stylebox_override("panel", Glaze.gloss(Color("#9b327b"), 23.0, 4.0))
	parent.add_child(tile)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -7)
	tile.add_child(stack)
	_label(stack, title, 16)
	return _label(stack, value, 37, tint)

func _orb(parent: Node, kind: String, caption: String, tint: Color, action: Callable) -> Button:
	var button := _button(parent, "+5" if kind == "moves" else "", action, tint, 65)
	button.tooltip_text = caption
	button.custom_minimum_size.x = 65
	button.size_flags_horizontal = Control.SIZE_FILL
	button.add_theme_font_size_override("font_size", 30)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tone := tint
		if state == "hover":
			tone = tint.lightened(0.16)
		elif state == "pressed":
			tone = tint.darkened(0.14)
		elif state == "disabled":
			tone = tint.darkened(0.43)
		button.add_theme_stylebox_override(state, Glaze.gloss(tone, 36.0, 5.0))
	_mark(button, kind, 0.66, 0.45)
	return button

func _make_goals(parent: HBoxContainer) -> void:
	var goal: Dictionary = game.level.goal
	goal_specs = []
	goal_values.clear()
	match str(goal.type):
		"palette":
			for target in goal.targets:
				goal_specs.append({"kind": "collect", "color": int(target.color), "total": int(target.count)})
		"collect", "mixed":
			goal_specs.append({"kind": "collect", "color": int(goal.color), "total": int(goal.count)})
			if goal.type == "mixed":
				goal_specs.append({"kind": "jelly"})
				goal_specs.append({"kind": "block"})
		"jelly": goal_specs.append({"kind": "jelly"})
		"blocks": goal_specs.append({"kind": "block"})
		_: goal_specs.append({"kind": "score", "total": int(goal.count)})
	for spec in goal_specs:
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", -3)
		stack.custom_minimum_size.x = 50
		parent.add_child(stack)
		var piece: int = int(spec.get("color", -1))
		var icon_kind: String = spec.kind
		if icon_kind == "score":
			piece = 3
		var icon := _icon(stack, icon_kind, 34, piece)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		goal_values.append(_label(stack, "", 17, Glaze.INK))

func show_pause() -> void:
	if busy:
		return
	_layout("pause")
	_spacer(body)
	var card := _card(body, BERRY)
	_label(card, word("استراحة في المملكة", "Kingdom break"), 32, Glaze.GOLD)
	_button(card, word("كمّل اللعب", "Resume"), _show_game, LIME)
	_button(card, word("إعادة المرحلة", "Restart level"), func() -> void: start_level(level_id), PLUM)
	_button(card, word("خريطة المراحل", "Level map"), show_map, DENIM)
	_button(card, word("الرئيسية", "Home"), show_home, PLUM)
	_spacer(body)

func _sum(layer: PackedInt32Array) -> int:
	var count := 0
	for hp in layer:
		count += hp
	return count

func _update(state: Dictionary) -> void:
	for index in goal_specs.size():
		var spec: Dictionary = goal_specs[index]
		var label := goal_values[index]
		match str(spec.kind):
			"collect":
				var collected := mini(int(state.collected[spec.color]), int(spec.total))
				label.text = "%d/%d" % [collected, spec.total]
			"jelly": label.text = str(_sum(state.jelly))
			"block": label.text = str(_sum(state.blocks))
			_: label.text = str(spec.total)
	moves_label.text = str(state.moves)
	score_label.text = word("النتيجة  %d", "Score  %d") % state.score
	var stars: Array = game.level.stars
	var earned := 0
	for threshold in stars:
		if state.score >= int(threshold):
			earned += 1
	point_bar.max_value = int(stars[2])
	point_bar.value = state.score
	star_line.text = "★".repeat(earned) + "☆".repeat(3 - earned)
	for kind in booster_buttons:
		var count := int(profile.data.stock.get(kind, 0))
		booster_badges[kind].text = str(count) if count > 0 else str(Profile.COST[kind])
		booster_buttons[kind].disabled = busy or resolved or not profile.can_spend(kind)
	_refresh_wallet()

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
