class_name Wardrobe
extends Control
## Spend coins on hats, faces, colours, teacups and death animations; wear the titles you've
## earned. The turntable shows your bean, and can ragdoll it with your chosen death.

signal closed

const TABS := [[&"hat", "HATS"], [&"face", "FACES"], [&"skin", "COLOURS"], [&"cup", "CUPS"], [&"death", "DEATHS"], [&"title", "TITLES"]]

var _category: StringName = &"hat"
var _list: VBoxContainer
var _tabs: Array[Button] = []
var _coins: HBoxContainer
var _viewport: SubViewport
var _stage: Node3D
var _guest: Guest
var _cup: TeaCup
var _preview_look: Dictionary = {}
var _spin := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.backdrop(self, 0.75)
	var p := Ui.panel(Ui.PLUM, 30, Vector4(26, 20, 26, 22))
	p.custom_minimum_size = Vector2(1080, 600)
	add_child(Ui.center(p))
	var v := Ui.vbox(12)
	p.add_child(v)
	var head := Ui.hbox(12)
	v.add_child(head)
	head.add_child(Ui.title("WARDROBE", 48, Ui.YELLOW))
	head.add_child(Ui.spacer(0, 0, true))
	_coins = Ui.hbox(10)
	head.add_child(_coins)
	head.add_child(Ui.button("DONE", func() -> void:
		Net.refresh_me()
		closed.emit(), Ui.MINT, 20, Vector2(120, 50)))
	var tabs := Ui.hbox(6)
	v.add_child(tabs)
	for t: Array in TABS:
		var b := Ui.tab(t[1])
		var cat: StringName = t[0]
		b.pressed.connect(func() -> void:
			Sfx.play(&"pop", -6.0)
			_category = cat
			_refresh())
		tabs.add_child(b)
		_tabs.append(b)
	var body := Ui.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = Ui.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var pv := Ui.vbox(10)
	body.add_child(pv)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Ui.box(Color("1b0f2b"), 24, 4, 6, Ui.INK, Vector4(4, 4, 4, 4)))
	pv.add_child(frame)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(400, 380)
	svc.stretch = true
	frame.add_child(svc)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_viewport)
	_build_stage()
	var ph := Ui.hbox(10)
	ph.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_child(ph)
	ph.add_child(Ui.button("TRY MY DEATH", func() -> void: _preview_death(), Ui.PINK, 18, Vector2(0, 50)))
	ph.add_child(Ui.button("CHEER", func() -> void:
		if _guest:
			_guest.gesture(&"cheer"), Ui.YELLOW, 18, Vector2(0, 50)))
	ph.add_child(Ui.button("BONK", func() -> void:
		if _guest:
			_guest.bonk(Vector3(0, 0, -1), Cake.FROSTINGS[randi() % Cake.FROSTINGS.size()]), Ui.ORANGE, 18, Vector2(0, 50)))
	_refresh()


func _build_stage() -> void:
	_stage = Node3D.new()
	_stage.name = "World"
	_viewport.add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9b3ff")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 0.9
	key.shadow_enabled = true
	_stage.add_child(key)
	Mats.mesh(_stage, Mats.cylinder(1.3, 1.35, 0.12, 40), Mats.solid(Ui.PINK, 0.6), Vector3(0, -0.06, 0))
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Guest.L_WORLD
	RoomBuilder._box_shape(floor_body, Vector3(20, 1, 20), Vector3(0, -0.5, 0))
	_stage.add_child(floor_body)
	var cam := Camera3D.new()
	cam.fov = 38.0
	_stage.add_child(cam)
	cam.transform = Transform3D(Basis(), Vector3(0, 1.7, 4.8)).looking_at(Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true
	_rebuild_guest(Profile.look())


func _rebuild_guest(look: Dictionary) -> void:
	_preview_look = look
	if _guest:
		_guest.clear_corpse()
		_guest.queue_free()
	if _cup:
		_cup.queue_free()
	_guest = Guest.new()
	_stage.add_child(_guest)
	_guest.setup(0, {"id": 0, "name": Profile.player_name, "cos": look})
	_guest.show_tags(false)
	_guest.stand()
	_guest.position = Vector3(0, 0, 0.1)
	_cup = TeaCup.new()
	_stage.add_child(_cup)
	_cup.setup(0, StringName(str(look.get("cup", &"porcelain"))))
	_cup.position = Vector3(1.0, 0.0, 0.7)
	_cup.set_filled(true)
	_spin = true


func _process(delta: float) -> void:
	if _guest and _guest.alive and _spin:
		_guest.rotation.y = sin(Time.get_ticks_msec() / 1400.0) * 0.8


func _preview_death() -> void:
	if _guest == null or not _guest.alive:
		return
	_spin = false
	var look := _preview_look
	_guest.rotation.y = 0.0
	var t := _guest.die(StringName(str(look.get("death", &"swoon"))))
	var tw := create_tween()
	tw.tween_interval(t + 2.2)
	tw.tween_callback(func() -> void: _rebuild_guest(look))


func _refresh() -> void:
	for i in _tabs.size():
		Ui.set_tab(_tabs[i], TABS[i][0] == _category)
	for c in _coins.get_children():
		c.queue_free()
	Ui.coin(_coins, Profile.coins, 24)
	_coins.add_child(Ui.chip("LEVEL %d" % Profile.level(), Ui.YELLOW, Ui.INK, 16))
	for c in _list.get_children():
		c.queue_free()
	var catalog: Dictionary = Cosmetics.TITLES if _category == &"title" else Cosmetics.CATEGORIES[_category]
	for id: StringName in catalog:
		var e: Dictionary = catalog[id]
		var owned := Profile.owns(_category, id)
		var equipped: bool = Profile.equipped.get(_category, &"") == id
		var row := Ui.card(Ui.YELLOW.lerp(Ui.CREAM, 0.5) if equipped else Ui.CREAM)
		var h := Ui.hbox(10)
		row.add_child(h)
		if _category == &"skin":
			h.add_child(Ui.chip("  ", e.get("body", Color.WHITE), Ui.INK, 18))
		var info := Ui.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(Ui.label(String(e["name"]), 19, Ui.INK, 700))
		var sub := ""
		if _category == &"title":
			sub = "Always yours." if e["stat"] == &"" else "Needs %s: %d (you have %d)" % [String(e["stat"]).replace("_", " "), int(e["need"]), Profile.stat(e["stat"])]
		elif e.has("desc"):
			sub = String(e["desc"])
		if sub != "":
			info.add_child(Ui.label(sub, 14, Color(Ui.INK, 0.6)))
		if _category != &"title":
			h.add_child(Ui.button("TRY", func() -> void:
				var look := Profile.look()
				look[String(_category)] = id
				_rebuild_guest(look)
				if _category == &"death":
					_preview_death(), Ui.SKY, 15, Vector2(70, 40)))
		if equipped:
			h.add_child(Ui.chip("WEARING", Ui.MINT, Ui.INK, 14))
		elif owned:
			h.add_child(Ui.button("WEAR", func() -> void:
				Profile.equip(_category, id)
				Sfx.play(&"gift", -4.0)
				_rebuild_guest(Profile.look())
				_refresh(), Ui.MINT, 15, Vector2(80, 40)))
		else:
			var why := Profile.can_buy(_category, id)
			var price := int(e.get("price", 0))
			if why == "":
				h.add_child(Ui.button("BUY %d" % price, func() -> void:
					if Profile.buy(_category, id):
						Sfx.play(&"coins", -2.0)
						_rebuild_guest(Profile.look())
						_refresh(), Ui.YELLOW, 15, Vector2(100, 40)))
			else:
				h.add_child(Ui.label(("%d coins, " % price if price > 0 else "") + why.to_lower(), 14, Color("b0184a"), 700))
		_list.add_child(row)
