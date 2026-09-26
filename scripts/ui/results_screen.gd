class_name ResultsScreen
extends Control
## After the last cup: who won and why, everyone's evening, and what you earned.

signal back_to_lobby
signal leave


func show_result(res: Dictionary, my_seat: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.backdrop(self, 0.55)
	var p := Ui.panel(Ui.PLUM, 30, Vector4(30, 24, 30, 24))
	p.custom_minimum_size = Vector2(680, 0)
	add_child(Ui.center(p))
	var v := Ui.vbox(10)
	p.add_child(v)
	var winners: Array = res.get("winners", [])
	var seats: Array = res.get("seats", [])
	var won := winners.has(my_seat)
	var t := Ui.title("YOU WIN!!" if won else "PARTY'S OVER", 70, Ui.MINT if won else Ui.PINK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var why := Ui.wrap(Ui.label(String(res.get("reason", "")), 20, Ui.YELLOW, 700), 620)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(why)
	for i in seats.size():
		var s: Dictionary = seats[i]
		var row := Ui.card(Ui.YELLOW.lerp(Ui.CREAM, 0.4) if winners.has(i) else Ui.CREAM)
		var h := Ui.hbox(10)
		row.add_child(h)
		var extra := ""
		if s.get("role", &"guest") == &"butler":
			extra = "  (THE BUTLER)"
		elif int(s.get("team", -1)) >= 0:
			extra = "  (%s)" % Defs.TEAM_NAMES[int(s["team"])]
		var nm := Ui.label(("WINNER  " if winners.has(i) else "") + String(s["name"]) + extra + ("  - you" if i == my_seat else ""), 18, Ui.INK, 700)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(Ui.label("survived" if s["alive"] else "died in round %d" % int(s["died_round"]), 15, Color(Ui.INK, 0.6)))
		h.add_child(Ui.chip("%d KILLS" % int(s["kills"]), Ui.PINK if int(s["kills"]) > 0 else Ui.LILAC, Ui.INK, 14))
		v.add_child(row)
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
	bh.add_child(Ui.button("AGAIN! (BACK TO LOBBY)", func() -> void: back_to_lobby.emit(), Ui.MINT, 26, Vector2(380, 66)))
	Ui.pop_in(p)
	Sfx.play(&"kazoo" if won else &"sting", -2.0)
