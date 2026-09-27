class_name OnlinePanel
extends Control
## Play online: Steam first (Spacewar / App ID 480: invite friends, public parties, join by code),
## with direct IP / LAN underneath as a fallback.

signal closed

var _list: VBoxContainer
var _status: Label
var _code: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.backdrop(self, 0.75)
	var p := Ui.panel(Ui.PLUM, 30, Vector4(30, 24, 30, 24))
	p.custom_minimum_size = Vector2(860, 0)
	add_child(Ui.center(p))
	var v := Ui.vbox(14)
	p.add_child(v)
	var head := Ui.hbox(12)
	v.add_child(head)
	head.add_child(Ui.title("PLAY ONLINE", 50, Ui.SKY))
	head.add_child(Ui.spacer(0, 0, true))
	head.add_child(Ui.button("CLOSE", func() -> void: closed.emit(), Ui.PLUM_LIGHT, 18, Vector2(120, 46)))

	var steam := Ui.card(Color("243a6b"), Vector4(18, 14, 18, 16))
	v.add_child(steam)
	var sv := Ui.vbox(10)
	steam.add_child(sv)
	var sh := Ui.hbox(10)
	sv.add_child(sh)
	sh.add_child(Ui.title("STEAM", 30, Ui.CREAM))
	if Steamworks.available:
		sh.add_child(Ui.chip("CONNECTED AS %s" % Steamworks.persona.to_upper(), Ui.MINT, Ui.INK, 15))
		var hb := Ui.hbox(12)
		sv.add_child(hb)
		hb.add_child(Ui.button("HOST FOR FRIENDS", func() -> void: _host(false), Ui.MINT, 22, Vector2(260, 60)))
		hb.add_child(Ui.button("HOST PUBLIC", func() -> void: _host(true), Ui.YELLOW, 22, Vector2(200, 60)))
		sv.add_child(Ui.label("Friends: host, then press INVITE FRIENDS in the lobby, or give them the party code.", 15, Ui.MUTED))
		var jh := Ui.hbox(10)
		sv.add_child(jh)
		_code = Ui.line_edit("", "Party code (numbers)", 300)
		jh.add_child(_code)
		jh.add_child(Ui.button("JOIN", func() -> void:
			var c := _code.text.strip_edges().replace(" ", "")
			if c.is_valid_int():
				_status.text = "Joining..."
				Steamworks.join_lobby(int(c))
			else:
				_status.text = "That code should be a long number.", Ui.SKY, 20, Vector2(120, 48)))
		jh.add_child(Ui.button("FIND PUBLIC PARTIES", func() -> void:
			_status.text = "Looking..."
			Steamworks.refresh_lobbies(), Ui.LILAC, 18, Vector2(0, 48)))
		jh.add_child(Ui.button("LOG", func() -> void:
			var lines := Steamworks.log_lines.slice(maxi(0, Steamworks.log_lines.size() - 12))
			DisplayServer.clipboard_set("\n".join(Steamworks.log_lines))
			_status.text = "Connection log (copied to your clipboard):\n" + "\n".join(lines), Ui.PLUM_LIGHT, 16, Vector2(70, 48)))
		_list = Ui.vbox(6)
		sv.add_child(_list)
		Steamworks.lobby_list.connect(_on_list)
	else:
		sh.add_child(Ui.chip("NOT CONNECTED", Ui.PINK, Ui.CREAM, 15))
		sv.add_child(Ui.wrap(Ui.label(Steamworks.reason, 17, Ui.CREAM), 760))
		sv.add_child(Ui.wrap(Ui.label("Open the Steam app, log in (not Offline Mode), then restart Tea Party. The game uses Steam's free test app Spacewar (480), so Steam shows you as playing Spacewar.", 15, Ui.MUTED), 760))

	var lan := Ui.card(Ui.PLUM_DARK, Vector4(18, 12, 18, 14))
	v.add_child(lan)
	var lv := Ui.vbox(8)
	lan.add_child(lv)
	lv.add_child(Ui.title("SAME WI-FI / DIRECT IP", 22, Ui.CREAM))
	var lh := Ui.hbox(10)
	lv.add_child(lh)
	lh.add_child(Ui.button("HOST", func() -> void:
		if Net.host_game() != OK:
			_status.text = "Couldn't open UDP port %d." % Net.DEFAULT_PORT, Ui.LILAC, 18, Vector2(120, 46)))
	var ip := Ui.line_edit(str(Profile.settings.get("last_ip", "127.0.0.1")), "Host IP address", 220)
	lh.add_child(ip)
	lh.add_child(Ui.button("JOIN IP", func() -> void:
		Profile.set_setting("last_ip", ip.text.strip_edges())
		_status.text = "Knocking on the door..."
		Net.join_game(ip.text), Ui.LILAC, 18, Vector2(140, 46)))
	_status = Ui.wrap(Ui.label("", 17, Ui.YELLOW, 700, 6), 760)
	v.add_child(_status)
	Net.connection_failed.connect(func(reason: String) -> void:
		if is_instance_valid(_status):
			_status.text = reason)
	Net.join_progress.connect(func(text: String) -> void:
		if is_instance_valid(_status):
			_status.text = text)


func _host(public: bool) -> void:
	_status.text = "Setting the table..."
	Net.host_steam(public)


func _on_list(lobbies: Array) -> void:
	if not is_instance_valid(_list):
		return
	for c in _list.get_children():
		c.queue_free()
	_status.text = "%d public tea part%s found." % [lobbies.size(), "y" if lobbies.size() == 1 else "ies"]
	for l: Dictionary in lobbies:
		var row := Ui.card(Ui.CREAM)
		var h := Ui.hbox(10)
		row.add_child(h)
		var nm := Ui.label(String(l["name"]) if String(l["name"]) != "" else "A tea party", 18, Ui.INK, 700)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(Ui.label("%d / %d" % [int(l["members"]), int(l["max"])], 16, Ui.INK, 600))
		var id := int(l["id"])
		h.add_child(Ui.button("JOIN", func() -> void: Steamworks.join_lobby(id), Ui.MINT, 16, Vector2(90, 40)))
		_list.add_child(row)
