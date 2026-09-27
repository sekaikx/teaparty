extends Node
## The whole app in one scene: a 3D slot ("World": the menu backdrop or the tea table) and a UI
## layer with the current screen (title, lobby, HUD, results) plus overlays (online, wardrobe,
## settings, tutorial).

var _world: Node3D
var _ui: CanvasLayer
var _screen: Control
var _overlay: Control
var _hud: GameHud
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween
var _toast_layer: CanvasLayer


func _ready() -> void:
	# Merged into the engine's default theme so every Control (even under CanvasLayers) uses it.
	ThemeDB.get_default_theme().merge_with(Ui.theme())
	ThemeDB.get_default_theme().default_font = Ui.body_font(600)
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 20
	add_child(toast_layer)
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", Ui.box(Ui.PINK, 18, 4, 6, Ui.INK, Vector4(20, 10, 20, 12)))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = Ui.wrap(Ui.label("", 18, Ui.CREAM, 700), 600)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.visible = false
	toast_layer.add_child(_toast)
	Ui.pin(_toast, Vector2(0.5, 1), Vector2(0.5, 1), Vector2(0, -100))
	_toast_layer = toast_layer
	Steamworks.invited.connect(_on_invited)
	Net.joined_lobby.connect(_show_lobby)
	Net.left_lobby.connect(func(reason: String) -> void:
		_show_title()
		if reason != "":
			toast(reason))
	Net.connection_failed.connect(func(reason: String) -> void:
		if not (_overlay is OnlinePanel):
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


## F11 or Alt+Enter: fullscreen <-> window, from anywhere.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed)):
		var fs := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		Profile.set_setting("fullscreen", not fs)
		get_viewport().set_input_as_handled()


## A Steam friend invited you: a popup with JOIN (works from anywhere, even mid-game).
func _on_invited(from_name: String, lobby: int) -> void:
	var p := Ui.panel(Ui.SKY, 22, Vector4(20, 14, 20, 16))
	var v := Ui.vbox(8)
	p.add_child(v)
	v.add_child(Ui.title("%s INVITED YOU!" % from_name.to_upper(), 28, Ui.CREAM))
	v.add_child(Ui.label("Join their tea party?" + (" (You'll leave this one.)" if Net.in_lobby else ""), 17, Ui.INK, 700))
	var h := Ui.hbox(10)
	v.add_child(h)
	h.add_child(Ui.button("JOIN", func() -> void:
		p.queue_free()
		if Net.in_lobby or Session.running:
			Net.leave()
		Steamworks.join_lobby(lobby), Ui.MINT, 22, Vector2(140, 54)))
	h.add_child(Ui.button("NOT NOW", func() -> void: p.queue_free(), Ui.PLUM_LIGHT, 18, Vector2(140, 54)))
	_toast_layer.add_child(p)
	Ui.pin(p, Vector2(1, 0), Vector2(1, 0), Vector2(-20, 250))
	Ui.pop_in(p)
	Sfx.play(&"bell", -2.0)
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


func toast(text: String, seconds: float = 4.0) -> void:
	_toast_label.text = text
	_toast.visible = true
	Ui.pop_in(_toast)
	if _toast_tw and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(seconds)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tw.tween_callback(func() -> void: _toast.visible = false)


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
		Ui.fade_in(c, 0.25)


func _open_overlay(c: Control) -> void:
	_close_overlay()
	_overlay = c
	_ui.add_child(c)
	Ui.fade_in(c, 0.15)
	Sfx.play(&"pop", -4.0)


func _close_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
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
	m.online_requested.connect(func() -> void:
		var o := OnlinePanel.new()
		o.closed.connect(_close_overlay)
		_open_overlay(o))
	m.tutorial_requested.connect(_open_tutorial)
	_set_screen(m)


func _show_lobby() -> void:
	_backdrop()
	var l := LobbyScreen.new()
	l.wardrobe_requested.connect(_open_wardrobe)
	_set_screen(l)
	if Net.is_host():
		Steamworks.set_lobby_joinable(true)


func _open_wardrobe() -> void:
	var w := Wardrobe.new()
	w.closed.connect(func() -> void:
		_close_overlay()
		if _screen is MainMenu:
			_set_world(MenuBackdrop.new())
			_show_title())
	_open_overlay(w)


func _open_settings() -> void:
	var s := SettingsPanel.new()
	s.closed.connect(_close_overlay)
	_open_overlay(s)


func _open_tutorial() -> void:
	var t := Tutorial.new()
	t.closed.connect(func() -> void: _overlay = null)
	_open_overlay(t)
	Profile.set_setting("tutorial_seen", true)


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
	Sfx.set_helium(bool(Session.match_rules.get("helium", false)))


func _show_results(res: Dictionary) -> void:
	var r := ResultsScreen.new()
	var tw := create_tween()
	# Let the last collapse play before the curtain.
	tw.tween_interval(2.2)
	tw.tween_callback(func() -> void:
		Engine.time_scale = 1.0
		if _hud:
			_hud.queue_free()
			_hud = null
		r.back_to_lobby.connect(func() -> void:
			Sfx.set_helium(false)
			if not Net.is_host():
				Net.set_ready(false)
			if Net.in_lobby:
				_show_lobby()
			else:
				_show_title())
		r.leave.connect(func() -> void: Net.leave())
		r.play_again.connect(func() -> void:
			Sfx.set_helium(false)
			if Net.can_start() == "":
				Net.start_match()
			else:
				_show_lobby()
				toast(Net.can_start()))
		_set_screen(r)
		r.show_result(res, Session.my_seat))
