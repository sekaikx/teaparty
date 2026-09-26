extends Node
## The whole app in one scene: a 3D slot ("World": the menu backdrop or the tea table) and a UI
## layer with the current screen (title, lobby, HUD, results) plus overlays (wardrobe, settings).

var _world: Node3D
var _ui: CanvasLayer
var _screen: Control
var _overlay: Control
var _hud: GameHud
var _toast: Label
var _toast_tw: Tween


func _ready() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_toast = UiKit.label("", 16, UiKit.hs.light, &"sans", 800)
	UiKit.pin(_toast, Vector2(0.5, 1), Vector2(0.5, 1), Vector2(0, -60))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 20
	add_child(toast_layer)
	toast_layer.add_child(_toast)
	Net.joined_lobby.connect(_show_lobby)
	Net.left_lobby.connect(func(reason: String) -> void:
		_show_title()
		if reason != "":
			toast(reason))
	Net.connection_failed.connect(func(reason: String) -> void:
		_show_title()
		toast(reason))
	Session.match_began.connect(_start_game)
	Session.match_over.connect(_show_results)
	_show_title()
	if "--qa" in OS.get_cmdline_user_args():
		var tool := "res://tools/qa_driver.gd"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--tool="):
				tool = a.get_slice("=", 1)
		add_child((load(tool) as GDScript).new())


func toast(text: String, seconds: float = 3.5) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tw and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(seconds)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _set_world(w: Node3D) -> void:
	if _world:
		_world.name = "OldWorld"
		_world.queue_free()
	_world = w
	if w:
		add_child(w)


func _set_screen(c: Control) -> void:
	_close_overlay()
	if _screen:
		_screen.queue_free()
	if _hud:
		_hud.queue_free()
		_hud = null
	_screen = c
	if c:
		_ui.add_child(c)
		UiKit.fade_in(c, 0.25)


func _open_overlay(c: Control) -> void:
	_close_overlay()
	_overlay = c
	_ui.add_child(c)
	UiKit.fade_in(c, 0.2)
	Sfx.play(&"open", -4.0)


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _backdrop() -> void:
	if not (_world is MenuBackdrop):
		_set_world(MenuBackdrop.new())


# ---------------------------------------------------------------- screens

func _show_title() -> void:
	_backdrop()
	var m := MainMenu.new()
	m.wardrobe_requested.connect(_open_wardrobe)
	m.settings_requested.connect(_open_settings)
	_set_screen(m)


func _show_lobby() -> void:
	_backdrop()
	var l := LobbyScreen.new()
	l.wardrobe_requested.connect(_open_wardrobe)
	_set_screen(l)


func _open_wardrobe() -> void:
	var w := Wardrobe.new()
	w.closed.connect(func() -> void:
		_close_overlay()
		if _screen is MainMenu:
			_show_title()
			if _world is MenuBackdrop:
				_set_world(MenuBackdrop.new()))
	_open_overlay(w)


func _open_settings() -> void:
	var s := SettingsPanel.new()
	s.closed.connect(_close_overlay)
	_open_overlay(s)


func _start_game() -> void:
	var table := TableView.new()
	_set_world(table)
	table.build(Session.roster, Session.match_rules, Session.my_seat)
	_set_screen(null)
	_hud = GameHud.new()
	add_child(_hud)
	_hud.setup(table)
	_hud.leave_requested.connect(func() -> void: Net.leave())
	_hud.settings_requested.connect(_open_settings)


func _show_results(res: Dictionary) -> void:
	var r := ResultsScreen.new()
	var tw := create_tween()
	# Let the last collapse play before the curtain.
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void:
		if _hud:
			_hud.queue_free()
			_hud = null
		r.back_to_lobby.connect(func() -> void:
			if not Net.is_host():
				Net.set_ready(false)
			if Net.in_lobby:
				_show_lobby()
			else:
				_show_title())
		r.leave.connect(func() -> void: Net.leave())
		_set_screen(r)
		r.show_result(res, Session.my_seat))
