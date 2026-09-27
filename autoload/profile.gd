extends Node
## The local player's save: name, XP / level, coins, owned and equipped cosmetics, lifetime
## stats (which unlock titles) and settings. Stored in user://teaparty_profile.cfg.

signal changed

const PATH := "user://teaparty_profile.cfg"
const STAT_KEYS := [&"matches", &"wins", &"kills", &"deaths", &"rounds_survived", &"sniffs", &"toasts",
	&"swaps", &"peeks", &"rattles", &"butler_wins", &"cake_hits", &"saves"]

var player_name := "Guest"
var xp := 0
var coins := 150
var owned: Array[String] = []
var equipped: Dictionary = Cosmetics.DEFAULT_EQUIP.duplicate()
var stats: Dictionary = {}
var settings := {"master": 0.9, "music": 0.55, "sfx": 0.85, "voice": 1.0, "mic": true,
	"fullscreen": true, "last_ip": "127.0.0.1", "tutorial_seen": false, "quality": "high", "settings_version": 2}
## On Steam, show your Steam name instead of the typed one.
var use_steam_name := true
## Tests and the QA harness set this so they never touch the real save.
var ephemeral := false


func _ready() -> void:
	for k: StringName in STAT_KEYS:
		stats[k] = 0
	if OS.get_cmdline_user_args().has("--ephemeral"):
		ephemeral = true
	load_profile()
	_apply_settings()


# ---------------------------------------------------------------- levels

static func xp_to_next(level_: int) -> int:
	return 100 + 50 * (level_ - 1)


func level() -> int:
	var l := 1
	var left := xp
	while left >= xp_to_next(l):
		left -= xp_to_next(l)
		l += 1
	return l


## XP into the current level and the size of the level, for a progress bar.
func level_progress() -> Vector2i:
	var l := 1
	var left := xp
	while left >= xp_to_next(l):
		left -= xp_to_next(l)
		l += 1
	return Vector2i(left, xp_to_next(l))


func stat(key: StringName) -> int:
	return level() if key == &"level" else int(stats.get(key, 0))


# ---------------------------------------------------------------- cosmetics

func owns(category: StringName, id: StringName) -> bool:
	if category == &"title":
		var t: Dictionary = Cosmetics.TITLES.get(id, {})
		return not t.is_empty() and (t["stat"] == &"" or stat(t["stat"]) >= int(t["need"]))
	var e := Cosmetics.entry(category, id)
	return int(e.get("price", 0)) == 0 or owned.has("%s:%s" % [category, id])


func can_buy(category: StringName, id: StringName) -> String:
	if owns(category, id):
		return "Owned"
	var e := Cosmetics.entry(category, id)
	if level() < int(e.get("level", 1)):
		return "Reach level %d" % int(e["level"])
	if coins < int(e.get("price", 0)):
		return "Not enough coins"
	return ""


func buy(category: StringName, id: StringName) -> bool:
	if can_buy(category, id) != "":
		return false
	coins -= int(Cosmetics.entry(category, id)["price"])
	owned.append("%s:%s" % [category, id])
	equip(category, id)
	return true


func equip(category: StringName, id: StringName) -> void:
	if not owns(category, id):
		return
	equipped[category] = id
	save_profile()
	changed.emit()


## The look sent to other players.
func look() -> Dictionary:
	return {"hat": equipped[&"hat"], "cup": equipped[&"cup"], "death": equipped[&"death"],
		"skin": equipped[&"skin"], "title": equipped[&"title"]}


func titles_unlocked() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Cosmetics.TITLES:
		if owns(&"title", id):
			out.append(id)
	return out


func is_unlocked_room(id: StringName) -> bool:
	return level() >= int(Defs.ROOMS[id]["level"])


func is_unlocked_mode(id: StringName) -> bool:
	return level() >= int(Defs.MODES[id]["level"])


func custom_rules_unlocked() -> bool:
	return level() >= Defs.CUSTOM_RULES_LEVEL


# ---------------------------------------------------------------- rewards

## Applies one match's result for this player. `me` = the seat's final stats from the host.
## Returns a summary for the results screen: xp, coins, levels gained, new titles, unlocks.
func award(me: Dictionary, won: bool, was_butler: bool, awards: int = 0, fun: Dictionary = {}) -> Dictionary:
	var before_level := level()
	var before_titles := titles_unlocked()
	var survived := int(me.get("rounds_survived", 0))
	var kills := int(me.get("kills", 0))
	var gained_xp := 30 + 15 * survived + 25 * kills + (120 if won else 0)
	var gained_coins := 15 + 10 * survived + 15 * kills + (75 if won else 0) + 25 * awards
	stats[&"cake_hits"] = int(stats.get(&"cake_hits", 0)) + int(fun.get("hits", 0))
	stats[&"saves"] = int(stats.get(&"saves", 0)) + int(fun.get("saves", 0))
	xp += gained_xp
	coins += gained_coins
	stats[&"matches"] += 1
	if won:
		stats[&"wins"] += 1
		if was_butler:
			stats[&"butler_wins"] += 1
	if not bool(me.get("alive", true)):
		stats[&"deaths"] += 1
	for k: StringName in [&"kills", &"rounds_survived", &"sniffs", &"toasts", &"swaps", &"peeks"]:
		stats[k] += int(me.get(String(k), 0))
	stats[&"rattles"] += int(me.get("rattles_used", 0))
	var levels := level() - before_level
	coins += 50 * levels
	var new_titles: Array = []
	for t in titles_unlocked():
		if not before_titles.has(t):
			new_titles.append(Cosmetics.title_name(t))
	var unlocks: Array = []
	for l in range(before_level + 1, level() + 1):
		for id: StringName in Defs.ROOMS:
			if int(Defs.ROOMS[id]["level"]) == l:
				unlocks.append("Room: " + String(Defs.ROOMS[id]["name"]))
		for id: StringName in Defs.MODES:
			if int(Defs.MODES[id]["level"]) == l:
				unlocks.append("Mode: " + String(Defs.MODES[id]["name"]))
		if l == Defs.CUSTOM_RULES_LEVEL:
			unlocks.append("Custom lobby rules")
	save_profile()
	changed.emit()
	return {"xp": gained_xp, "coins": gained_coins + 50 * levels, "levels": levels, "level": level(),
		"titles": new_titles, "unlocks": unlocks}


# ---------------------------------------------------------------- settings

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()
	save_profile()


func _apply_settings() -> void:
	for pair in [["Master", "master"], ["Music", "music"], ["SFX", "sfx"], ["Voice", "voice"]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus >= 0:
			var v := float(settings.get(pair[1], 1.0))
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(bus, v <= 0.001)
	if not ephemeral and DisplayServer.get_name() != "headless":
		_apply_window(bool(settings.get("fullscreen", true)))
	_apply_quality()


## Fullscreen (borderless, the desktop resolution) or a big centred window.
func _apply_window(fs: bool) -> void:
	var mode := DisplayServer.window_get_mode()
	var is_fs := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if fs and not is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fs and (is_fs or mode == DisplayServer.WINDOW_MODE_MINIMIZED):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var scr := DisplayServer.window_get_current_screen()
		var area := DisplayServer.screen_get_usable_rect(scr)
		var size := Vector2i(area.size * 0.8)
		# Keep 16:9.
		size.y = mini(size.y, size.x * 9 / 16)
		size.x = size.y * 16 / 9
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(area.position + (area.size - size) / 2)


## "high" or "low" (for weaker laptops: no MSAA, lower 3D resolution, fewer shadows).
func _apply_quality() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var low := String(settings.get("quality", "high")) == "low"
	tree.root.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	tree.root.scaling_3d_scale = 0.75 if low else 1.0
	tree.root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if low else Viewport.SCALING_3D_MODE_BILINEAR
	RenderingServer.directional_shadow_atlas_set_size(2048 if low else 4096, true)
	tree.root.positional_shadow_atlas_size = 1024 if low else 4096


# ---------------------------------------------------------------- save

func save_profile() -> void:
	if ephemeral:
		return
	var cf := ConfigFile.new()
	cf.set_value("player", "name", player_name)
	cf.set_value("player", "xp", xp)
	cf.set_value("player", "coins", coins)
	cf.set_value("player", "owned", owned)
	var eq := {}
	for k: StringName in equipped:
		eq[String(k)] = String(equipped[k])
	cf.set_value("player", "equipped", eq)
	var st := {}
	for k: StringName in stats:
		st[String(k)] = stats[k]
	cf.set_value("player", "stats", st)
	cf.set_value("player", "settings", settings)
	cf.save(PATH)


func load_profile() -> void:
	if ephemeral:
		return
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		player_name = "Guest %d" % randi_range(100, 999)
		return
	player_name = String(cf.get_value("player", "name", player_name))
	xp = int(cf.get_value("player", "xp", 0))
	coins = int(cf.get_value("player", "coins", 150))
	owned.clear()
	for o: Variant in cf.get_value("player", "owned", []):
		owned.append(String(o))
	var eq: Dictionary = cf.get_value("player", "equipped", {})
	for k: String in eq:
		equipped[StringName(k)] = StringName(String(eq[k]))
	var st: Dictionary = cf.get_value("player", "stats", {})
	for k: String in st:
		stats[StringName(k)] = int(st[k])
	var se: Dictionary = cf.get_value("player", "settings", {})
	for k: String in se:
		settings[k] = se[k]
	# Older saves defaulted to a small window: move them to fullscreen once.
	if int(settings.get("settings_version", 1)) < 2:
		settings["fullscreen"] = true
		settings["settings_version"] = 2
