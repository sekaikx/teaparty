class_name Wardrobe
extends Control
## Spend coins on hats, teacups, death animations and skins; wear the titles you've earned.
## A turntable preview shows the guest (and can play their death).

signal closed

const TABS := [[&"hat", "Hats"], [&"cup", "Teacups"], [&"death", "Deaths"], [&"skin", "Guests"], [&"title", "Titles"]]

var _category: StringName = &"hat"
var _list: VBoxContainer
var _tabs: Array[Button] = []
var _coins: HBoxContainer
var _viewport: SubViewport
var _stage: Node3D
var _guest: Guest
var _cup: TeaCup
var _preview_look: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.hs.add_backdrop(self, 0.5)
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(980, 560)
	add_child(UiKit.center(p))
	var v := UiKit.vbox(8)
	p.add_child(v)
	var head := UiKit.hbox(12)
	v.add_child(head)
	head.add_child(UiKit.title("Wardrobe", 32))
	head.add_child(UiKit.spacer(0, 0, true))
	_coins = UiKit.hbox(4)
	head.add_child(_coins)
	head.add_child(UiKit.button("Done", func() -> void:
		Net.refresh_me()
		closed.emit()))
	var tabs := UiKit.hbox(4)
	v.add_child(tabs)
	for t: Array in TABS:
		var b := UiKit.hs.tab_button(t[1])
		var cat: StringName = t[0]
		b.pressed.connect(func() -> void:
			Sfx.play(&"page", -6.0)
			_category = cat
			_refresh())
		tabs.add_child(b)
		_tabs.append(b)
	var body := UiKit.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = UiKit.vbox(4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var pv := UiKit.vbox(6)
	body.add_child(pv)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(380, 380)
	svc.stretch = true
	pv.add_child(svc)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_viewport)
	_build_stage()
	var ph := UiKit.hbox(8)
	pv.add_child(ph)
	ph.add_child(UiKit.button("Preview death", func() -> void: _preview_death()))
	ph.add_child(UiKit.button("Cheer", func() -> void:
		if _guest:
			_guest.base(&"Cheer", 0.2)))
	_refresh()


func _build_stage() -> void:
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9a883")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.4
	key.shadow_enabled = true
	_stage.add_child(key)
	Mats.mesh(_stage, Mats.cylinder(1.2, 1.25, 0.12, 32), Mats.solid(Color("5a3a24"), 0.6), Vector3(0, -0.06, 0))
	var cam := Camera3D.new()
	cam.fov = 40.0
	_stage.add_child(cam)
	cam.transform = Transform3D(Basis(), Vector3(0, 1.9, 5.2)).looking_at(Vector3(0, 1.2, 0), Vector3.UP)
	cam.current = true
	_rebuild_guest(Profile.look())


func _rebuild_guest(look: Dictionary) -> void:
	_preview_look = look
	if _guest:
		_guest.queue_free()
	if _cup:
		_cup.queue_free()
	_guest = Guest.new()
	_stage.add_child(_guest)
	_guest.setup(0, {"id": 0, "name": Profile.player_name, "cos": look})
	_guest.base(&"Idle", 0.0)
	_cup = TeaCup.new()
	_stage.add_child(_cup)
	_cup.setup(0, StringName(str(look.get("cup", &"porcelain"))))
	_cup.position = Vector3(0.95, 0.0, 0.6)
	_cup.set_filled(true)


func _process(delta: float) -> void:
	if _guest and _guest.alive:
		_guest.rotation.y += delta * 0.5


func _preview_death() -> void:
	if _guest == null:
		return
	var look := _preview_look
	var t := _guest.die(StringName(str(look.get("death", &"swoon"))))
	var tw := create_tween()
	tw.tween_interval(t + 1.4)
	tw.tween_callback(func() -> void: _rebuild_guest(look))


func _refresh() -> void:
	for i in _tabs.size():
		UiKit.hs.set_tab_active(_tabs[i], TABS[i][0] == _category)
	for c in _coins.get_children():
		c.queue_free()
	UiKit.hs.coin_label(_coins, Profile.coins, 16)
	_coins.add_child(UiKit.label("   Level %d" % Profile.level(), 14, UiKit.hs.accent, &"serif", 650))
	for c in _list.get_children():
		c.queue_free()
	var catalog: Dictionary = Cosmetics.TITLES if _category == &"title" else Cosmetics.CATEGORIES[_category]
	for id: StringName in catalog:
		var e: Dictionary = catalog[id]
		var row := UiKit.panel(&"row")
		var h := UiKit.hbox(8)
		row.add_child(h)
		var info := UiKit.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UiKit.label(String(e["name"]), 16, Color(), &"serif", 650))
		var sub := ""
		if _category == &"title":
			sub = "Always yours." if e["stat"] == &"" else "Needs %s: %d (you: %d)" % [String(e["stat"]).replace("_", " "), int(e["need"]), Profile.stat(e["stat"])]
		elif e.has("desc"):
			sub = String(e["desc"])
		if sub != "":
			info.add_child(UiKit.label(sub, 12, UiKit.hs.text_soft))
		var owned := Profile.owns(_category, id)
		var equipped: bool = Profile.equipped.get(_category, &"") == id
		if _category != &"title" and _category != &"death":
			h.add_child(UiKit.button("Try", func() -> void:
				var look := Profile.look()
				look[String(_category)] = id
				_rebuild_guest(look)))
		elif _category == &"death":
			h.add_child(UiKit.button("Try", func() -> void:
				var look := Profile.look()
				look["death"] = id
				_rebuild_guest(look)
				_preview_death()))
		if equipped:
			h.add_child(UiKit.label("Wearing", 13, UiKit.hs.good, &"sans", 850))
		elif owned:
			h.add_child(UiKit.button("Wear", func() -> void:
				Profile.equip(_category, id)
				Sfx.play(&"gift", -4.0)
				_rebuild_guest(Profile.look())
				_refresh()))
		else:
			var why := Profile.can_buy(_category, id)
			var price := int(e.get("price", 0))
			if why == "":
				h.add_child(UiKit.button("Buy  %d" % price, func() -> void:
					if Profile.buy(_category, id):
						Sfx.play(&"coins", -2.0)
						_rebuild_guest(Profile.look())
						_refresh()))
			else:
				var lock := UiKit.label(("%d coins - " % price if price > 0 else "") + why, 12, UiKit.hs.accent, &"sans", 800)
				h.add_child(lock)
		_list.add_child(row)
