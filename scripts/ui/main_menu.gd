class_name MainMenu
extends Control
## Title screen: big buttons down the left, your profile top right, the party in the background.

signal wardrobe_requested
signal settings_requested
signal online_requested
signal tutorial_requested

var _status: Label
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.color = Color(Ui.PLUM_DARK, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var head := Ui.vbox(0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	Ui.pin(head, Vector2(0, 0), Vector2(0, 0), Vector2(46, 26))
	_title = Ui.title("TEA PARTY", 104, Ui.YELLOW)
	head.add_child(_title)
	var tag := Ui.chip("MURDER AT TEATIME  -  FIND THE POISONER", Ui.PINK, Ui.CREAM, 22)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(tag)

	var col := Ui.vbox(14)
	add_child(col)
	Ui.pin(col, Vector2(0, 1), Vector2(0, 1), Vector2(46, -40))
	col.add_child(Ui.button("PLAY NOW!", func() -> void: _play_now(), Ui.MINT, 34, Vector2(360, 80)))
	var d := Defs.daily_today()
	var done := String(Profile.settings.get("daily_done", "")) == Time.get_date_string_from_system()
	var db := Ui.button("DAILY: %s%s" % [String(d["name"]).to_upper(), "  (done!)" if done else "  +150"], func() -> void: Net.daily(), Ui.ORANGE, 17, Vector2(360, 46))
	db.tooltip_text = String(d["desc"])
	col.add_child(db)
	col.add_child(Ui.button("PARTY WITH BOTS (LOBBY)", func() -> void: Net.solo(), Ui.YELLOW, 20, Vector2(360, 52)))
	col.add_child(Ui.button("PLAY ONLINE", func() -> void: online_requested.emit(), Ui.SKY, 30, Vector2(360, 74)))
	var row := Ui.hbox(12)
	col.add_child(row)
	row.add_child(Ui.button("WARDROBE", func() -> void: wardrobe_requested.emit(), Ui.YELLOW, 18, Vector2(112, 58)))
	row.add_child(Ui.button("TROPHIES", func() -> void: _trophies(), Ui.ORANGE, 18, Vector2(112, 58)))
	row.add_child(Ui.button("HOW TO PLAY", func() -> void: tutorial_requested.emit(), Ui.PINK, 16, Vector2(112, 58)))
	var row2 := Ui.hbox(12)
	col.add_child(row2)
	row2.add_child(Ui.button("SETTINGS", func() -> void: settings_requested.emit(), Ui.LILAC, 18, Vector2(112, 50)))
	row2.add_child(Ui.button("CREDITS", func() -> void: _credits(), Ui.SKY, 18, Vector2(112, 50)))
	row2.add_child(Ui.button("QUIT", func() -> void: get_tree().quit(), Ui.PLUM_LIGHT, 18, Vector2(112, 50)))
	var ver := Ui.label("v%s" % ProjectSettings.get_setting("application/config/version", "1.0"), 14, Ui.MUTED, 700, 4)
	add_child(ver)
	Ui.pin(ver, Vector2(1, 1), Vector2(1, 1), Vector2(-16, -10))
	_status = Ui.wrap(Ui.label("", 16, Ui.PINK, 700, 6), 360)
	col.add_child(_status)

	var prof := Ui.panel(Ui.PLUM, 24, Vector4(20, 16, 20, 18))
	add_child(prof)
	Ui.pin(prof, Vector2(1, 0), Vector2(1, 0), Vector2(-30, 30))
	var pv := Ui.vbox(8)
	prof.add_child(pv)
	var steam_name := Steamworks.friendly_name()
	if steam_name != "":
		pv.add_child(Ui.label("Playing as", 14, Ui.MUTED))
		pv.add_child(Ui.title(steam_name, 30, Ui.CREAM))
		pv.add_child(Ui.chip("STEAM", Ui.SKY, Ui.INK, 14))
	else:
		pv.add_child(Ui.label("Your name", 14, Ui.MUTED))
		var name_edit := Ui.line_edit(Profile.player_name, "Your name", 240)
		name_edit.max_length = 20
		name_edit.text_changed.connect(func(t: String) -> void:
			Profile.player_name = t.strip_edges() if t.strip_edges() != "" else "Guest"
			Profile.save_profile())
		pv.add_child(name_edit)
	var lh := Ui.hbox(10)
	pv.add_child(lh)
	lh.add_child(Ui.chip("LEVEL %d" % Profile.level(), Ui.YELLOW, Ui.INK, 18))
	Ui.coin(lh, Profile.coins, 20)
	var prog := Profile.level_progress()
	var bar := Ui.bar(Ui.MINT, 14)
	bar.max_value = prog.y
	bar.value = prog.x
	pv.add_child(bar)
	pv.add_child(Ui.label("%s   -   %d / %d XP" % [Cosmetics.title_name(Profile.equipped[&"title"]), prog.x, prog.y], 14, Ui.MUTED))


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = sin(t * 1.3) * 0.03
	_title.scale = Vector2.ONE * (1.0 + sin(t * 2.1) * 0.015)


func show_status(text: String) -> void:
	if _status:
		_status.text = text


## First time with the new rules: the 5 how-to-play cards, then straight into a match.
func _play_now() -> void:
	if bool(Profile.settings.get("murder_rules_seen", false)):
		Net.quick_play()
		return
	Profile.set_setting("murder_rules_seen", true)
	var t := Tutorial.new()
	t.closed.connect(func() -> void: Net.quick_play())
	add_child(t)


func _credits() -> void:
	var c := CreditsPanel.new()
	add_child(c)
	c.closed.connect(c.queue_free)


func _trophies() -> void:
	var t := TrophiesPanel.new()
	add_child(t)
	t.closed.connect(t.queue_free)
