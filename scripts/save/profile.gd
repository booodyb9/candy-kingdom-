extends RefCounted
## Two journal slots. A write always leaves the last valid generation intact.

const VERSION := 1
const MAX_LIVES := 5
const REFILL := 20 * 60
const COST := {"hammer": 45, "moves": 70, "shuffle": 40, "color": 90}

var data: Dictionary
var notice := ""
var folder: String
var generation := 0
var last_seen := 0

func _init(path := "user://") -> void:
	folder = path
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	data = _defaults()
	var present := 0
	var readable := 0
	for slot in 2:
		var filename := folder.path_join("profile-%d.json" % slot)
		if not FileAccess.file_exists(filename):
			continue
		present += 1
		var record = JSON.parse_string(FileAccess.get_file_as_string(filename))
		if not _valid(record):
			continue
		readable += 1
		if int(record.sequence) > generation:
			generation = int(record.sequence)
			data = JSON.parse_string(record.payload)
	if present > readable:
		notice = "recovered" if readable > 0 else "damaged"
	last_seen = int(data.clock)
	refresh()

func _defaults() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	return {"unlocked": 1, "results": {}, "coins": 150, "lives": 5,
		"stock": {"hammer": 3, "moves": 2, "shuffle": 2, "color": 1},
		"clock": now, "refill_at": 0, "language": "ar", "music": 0.55,
		"sound": 0.7, "motion": true, "economy": false}

func _valid(record: Variant) -> bool:
	if not record is Dictionary or int(record.get("version", 0)) != VERSION:
		return false
	if not record.get("payload") is String or int(record.get("sequence", 0)) < 1:
		return false
	var payload: String = record.payload
	if payload.sha256_text() != record.get("hash"):
		return false
	var values = JSON.parse_string(payload)
	if not values is Dictionary:
		return false
	for key in _defaults():
		if not values.has(key):
			return false
	return values.results is Dictionary and values.stock is Dictionary and values.language in ["ar", "en"]

func save() -> bool:
	if notice == "damaged":
		# Leave both damaged files available for recovery until the player acknowledges.
		return false
	var next := generation + 1
	var payload := JSON.stringify(data)
	var file_name := folder.path_join("profile-%d.json" % (next % 2))
	var temp := file_name + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		notice = "write_failed"
		return false
	file.store_string(JSON.stringify({"version": VERSION, "sequence": next, "payload": payload, "hash": payload.sha256_text()}))
	file.flush()
	var status := file.get_error()
	file = null
	if status != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(file_name)) != OK:
		notice = "write_failed"
		return false
	generation = next
	if notice == "write_failed":
		notice = ""
	return true

func acknowledge_damage() -> void:
	if notice == "damaged":
		var stamp := int(Time.get_unix_time_from_system())
		for slot in 2:
			var path := ProjectSettings.globalize_path(folder.path_join("profile-%d.json" % slot))
			if FileAccess.file_exists(path) and DirAccess.rename_absolute(path, path + ".damaged-%d" % stamp) != OK:
				return
	notice = ""
	save()

func refresh(wall_clock := -1) -> bool:
	var now := int(Time.get_unix_time_from_system()) if wall_clock < 0 else wall_clock
	now = maxi(last_seen, now)
	last_seen = now
	var refill := int(data.refill_at)
	if refill <= 0 or now < refill or int(data.lives) >= MAX_LIVES:
		return false
	var restored := 1 + (now - refill) / REFILL
	data.lives = mini(MAX_LIVES, int(data.lives) + restored)
	data.refill_at = 0 if int(data.lives) == MAX_LIVES else refill + restored * REFILL
	data.clock = now
	return true

func lose_life() -> void:
	refresh()
	if int(data.lives) == MAX_LIVES:
		data.refill_at = last_seen + REFILL
	data.lives = maxi(0, int(data.lives) - 1)
	data.clock = last_seen
	save()

func can_spend(kind: String) -> bool:
	return COST.has(kind) and (int(data.stock.get(kind, 0)) > 0 or int(data.coins) >= int(COST[kind]))

func spend(kind: String) -> void:
	if int(data.stock.get(kind, 0)) > 0:
		data.stock[kind] = int(data.stock[kind]) - 1
	else:
		data.coins = int(data.coins) - int(COST[kind])
	save()

func win(level: Dictionary, score: int) -> Dictionary:
	var id := int(level.id)
	var key := str(id)
	var previous: Dictionary = data.results.get(key, {"score": 0, "stars": 0})
	var stars := 1
	for index in range(1, 3):
		if score >= int(level.stars[index]):
			stars = index + 1
	var coins := int(level.reward.first if int(previous.stars) == 0 else level.reward.replay)
	coins += maxi(0, stars - int(previous.stars)) * int(level.reward.star)
	data.results[key] = {"score": maxi(score, int(previous.score)), "stars": maxi(stars, int(previous.stars))}
	data.unlocked = mini(50, maxi(int(data.unlocked), id + 1))
	data.coins = int(data.coins) + coins
	save()
	return {"stars": stars, "coins": coins}
