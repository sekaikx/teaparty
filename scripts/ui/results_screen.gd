class_name ResultsScreen
extends Control
## After the last cup: who won and why, everyone's evening, and what you earned.

signal back_to_lobby
signal leave
signal play_again


func show_result(res: Dictionary, my_seat: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.backdrop(self, 0.55)
	var p := Ui.panel(Ui.PLUM, 30, Vector4(30, 24, 30, 24))
	p.custom_minimum_size = Vector2(1060, 0)
	add_child(Ui.center(p))
	var v := Ui.vbox(10)
	p.add_child(v)
	var winners: Array = res.get("winners", [])
	var seats: Array = res.get("seats", [])
	var won := winners.has(my_seat)
	var t := Ui.title("YOU WIN!!" if won else "PARTY'S OVER", 60, Ui.MINT if won else Ui.PINK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var why := Ui.wrap(Ui.label(String(res.get("reason", "")), 20, Ui.YELLOW, 700), 620)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(why)
	# Guests on the left, the evening's awards on the right.
	var cols := Ui.hbox(16)
	v.add_child(cols)
	var left := Ui.vbox(6)
	left.custom_minimum_size.x = 560
	cols.add_child(left)
	for i in seats.size():
		var s: Dictionary = seats[i]
		var row := Ui.card(Ui.YELLOW.lerp(Ui.CREAM, 0.4) if winners.has(i) else Ui.CREAM, Vector4(12, 4, 12, 4))
		var h := Ui.hbox(10)
		row.add_child(h)
		var extra := ""
		var rl := StringName(s.get("role", &"guest"))
		if rl == &"poisoner":
			extra = "  (THE POISONER)"
		elif rl in [&"inspector", &"physician"]:
			extra = "  (%s)" % Defs.role_name(rl).to_upper()
		var nm := Ui.label(("WINNER  " if winners.has(i) else "") + String(s["name"]) + extra + ("  - you" if i == my_seat else ""), 16, Ui.INK, 700)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(Ui.label("survived" if s["alive"] else ("thrown out in round %d" if s.get("ejected", false) else "poisoned in round %d") % int(s["died_round"]), 15, Color(Ui.INK, 0.6)))
		h.add_child(Ui.chip(("%d KILL" if int(s["kills"]) == 1 else "%d KILLS") % int(s["kills"]), Ui.PINK if int(s["kills"]) > 0 else Ui.LILAC, Ui.INK, 13))
		left.add_child(row)
	var awards: Array = res.get("awards", [])
	if not awards.is_empty():
		var grid := Ui.vbox(6)
		grid.custom_minimum_size.x = 420
		cols.add_child(grid)
		for a: Dictionary in awards:
			var card := Ui.card(Ui.LILAC.lerp(Ui.CREAM, 0.6) if int(a["seat"]) != my_seat else Ui.YELLOW, Vector4(12, 4, 12, 5))
			var av := Ui.vbox(0)
			card.add_child(av)
			av.add_child(Ui.title(String(a["title"]), 20, Ui.PINK))
			av.add_child(Ui.label("%s - %s" % [String(seats[int(a["seat"])]["name"]) if int(a["seat"]) < seats.size() else "?", String(a["desc"])], 14, Color(Ui.INK, 0.8), 700))
			grid.add_child(card)
	var award: Dictionary = res.get("award", {})
	if not award.is_empty():
		var ah := Ui.hbox(16)
		ah.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(ah)
		ah.add_child(Ui.title("+%d XP" % int(award["xp"]), 34, Ui.SKY))
		Ui.coin(ah, int(award["coins"]), 30)
		if int(award["levels"]) > 0:
			ah.add_child(Ui.title("LEVEL %d!" % int(award["level"]), 34, Ui.MINT))
			Sfx.play(&"fanfare")
		for tt: String in award.get("titles", []):
			v.add_child(Ui.label("New title: %s" % tt, 18, Ui.MINT, 700))
		for u: String in award.get("unlocks", []):
			v.add_child(Ui.label("Unlocked: %s" % u, 18, Ui.MINT, 700))
	var bh := Ui.hbox(14)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bh)
	bh.add_child(Ui.button("LEAVE", func() -> void: leave.emit(), Ui.PLUM_LIGHT, 22, Vector2(160, 62)))
	if Net.is_host():
		bh.add_child(Ui.button("LOBBY", func() -> void: back_to_lobby.emit(), Ui.YELLOW, 22, Vector2(160, 62)))
		var again := Ui.button("PLAY AGAIN!", func() -> void: play_again.emit(), Ui.MINT, 30, Vector2(300, 70))
		bh.add_child(again)
	else:
		bh.add_child(Ui.button("BACK TO LOBBY", func() -> void: back_to_lobby.emit(), Ui.MINT, 26, Vector2(320, 66)))
	Ui.pop_in(p)
	Sfx.play(&"kazoo" if won else &"sting", -2.0)
