extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene: PackedScene = load("res://scenes/kingdom.tscn")
	var ui = scene.instantiate()
	root.add_child(ui)
	ui.profile.data.motion = false
	ui.profile.data.unlocked = 12
	ui.profile.data.coins = 1350
	for id in range(1, 12):
		ui.profile.data.results[str(id)] = {"score": 1000, "stars": 2 + id % 2}
	ui.show_home()
	await _snapshot("home")
	ui.show_map()
	await _snapshot("map")
	ui.start_level(12, 147)
	await _snapshot("gameplay")
	ui.queue_free()
	await process_frame
	quit(0)

func _snapshot(key: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame == null or frame.is_empty():
		printerr("Missing viewport image " + key)
		quit(1)
		return
	var dir := OS.get_environment("SWEET_KINGDOM_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	if frame.save_png(dir.path_join(key + ".png")) != OK:
		printerr("Cannot write screenshot " + key)
		quit(1)
		return
	var height := roundi(303.0 * frame.get_height() / frame.get_width())
	frame.resize(303, height, Image.INTERPOLATE_LANCZOS)
	var encoded := Marshalls.raw_to_base64(frame.save_jpg_to_buffer(0.59))
	for start in range(0, encoded.length(), 3600):
		print("SWEET_PREVIEW_%s:%s" % [key, encoded.substr(start, 3600)])
