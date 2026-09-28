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
	if int(res.get("daily_bonus", 0)) > 0:
		v.add_child(Ui.label("DAILY CHALLENGE DONE: +%d coins" % int(res["daily_bonus"]), 20, Ui.ORANGE, 800))
	var ach: Array = res.get("achievements", [])
	if not ach.is_empty():
		var achbox := Ui.hbox(8)
		achbox.alignment = BoxContainer.ALIGNMENT_CENTER
		achbox.add_child(Ui.label("ACHIEVEMENT%s:" % ("S" if ach.size() > 1 else ""), 18, Ui.YELLOW, 800))
		for a: String in ach:
			achbox.add_child(Ui.chip(a, Ui.YELLOW, Ui.INK, 16))
		v.add_child(achbox)
		Sfx.play(&"fanfare", -8.0)
	var bh := Ui.hbox(14)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bh)
	bh.add_child(Ui.button("LEAVE", func() -> void: leave.emit(), Ui.PLUM_LIGHT, 22, Vector2(160, 62)))
	if not (res.get("history", []) as Array).is_empty():
		bh.add_child(Ui.button("WHO POURED WHAT?", func() -> void: _replay(res), Ui.SKY, 20, Vector2(230, 62)))
	if Net.is_host():
		bh.add_child(Ui.button("LOBBY", func() -> void: back_to_lobby.emit(), Ui.YELLOW, 22, Vector2(160, 62)))
		var again := Ui.button("PLAY AGAIN!", func() -> void: play_again.emit(), Ui.MINT, 30, Vector2(300, 70))
		bh.add_child(again)
	else:
		bh.add_child(Ui.button("BACK TO LOBBY", func() -> void: back_to_lobby.emit(), Ui.MINT, 26, Vector2(320, 66)))
	Ui.pop_in(p)
	Sfx.play(&"kazoo" if won else &"sting", -2.0)


# ---------------------------------------------------------------- the replay card

## Every round laid bare: who poured what into whose cup, who used which item, who fell and who
## was thrown out. The "I KNEW IT!" screen.
func _replay(res: Dictionary) -> void:
	var seats: Array = res.get("seats", [])
	var nm := func(i: int) -> String: return String(seats[i]["name"]) if i >= 0 and i < seats.size() else "?"
	var col := func(i: int) -> Color:
		if i < 0 or i >= seats.size():
			return Color.WHITE
		var cos: Dictionary = seats[i].get("cos", {})
		return Cosmetics.entry(&"skin", StringName(str(cos.get("skin", &"cream")))).get("body", Color.WHITE)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	Ui.backdrop(layer, 0.7)
	var p := Ui.panel(Ui.PLUM_DARK, 26, Vector4(24, 18, 24, 18))
	p.custom_minimum_size = Vector2(880, 0)
	layer.add_child(Ui.center(p))
	var v := Ui.vbox(8)
	p.add_child(v)
	v.add_child(Ui.title("WHO POURED WHAT", 40, Ui.YELLOW))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(840, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := Ui.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var line := func(parts: Array, colour: Color = Ui.CREAM) -> void:
		# parts: strings and seat ints (drawn as a colour dot + name).
		var h := Ui.hbox(5)
		for part: Variant in parts:
			if part is int:
				h.add_child(Ui.dot(col.call(int(part)), 13))
				h.add_child(Ui.label(nm.call(int(part)), 15, colour, 800))
			else:
				h.add_child(Ui.label(String(part), 15, colour, 600))
		list.add_child(h)
	for rd: Dictionary in res.get("history", []):
		var head := "ROUND %d" % int(rd["round"])
		if String(rd.get("twist", "")) != "":
			head += "   (%s)" % String(Defs.TWISTS.get(StringName(rd["twist"]), {}).get("name", ""))
		list.add_child(Ui.label(head, 20, Ui.PINK, 800))
		for pr: Array in rd.get("pours", []):
			var k := int(pr[1])
			var bad := k == Defs.Ingredient.POISON
			line.call([int(pr[0]), "poured %s into" % Defs.ingredient_name(k).to_upper(), int(pr[2]), "'s cup" + ("   <- POISON" if bad else "")],
				Color("ff8fb0") if bad else Ui.CREAM)
		for it: Array in rd.get("items", []):
			var targets: Array = it[2]
			var parts: Array = [int(it[0]), "used %s on" % Defs.item_name(int(it[1])).to_upper()]
			for t: Variant in targets:
				parts.append(int(t))
			line.call(parts, Ui.SKY)
		for d: Dictionary in rd.get("drinks", []):
			if d["died"]:
				line.call([int(d["seat"]), "drank poison and FELL"], Color("ff6f91"))
			elif d.get("revived", false):
				line.call([int(d["seat"]), "drank poison... and the Physician REVIVED them"], Ui.MINT)
			else:
				line.call([int(d["seat"]), "had poison in their cup, but an ANTIDOTE saved them"], Ui.MINT)
		var ej := int(rd.get("ejected", -1))
		if ej >= 0:
			var role := String(rd.get("ejected_role", ""))
			line.call(["Thrown out:", ej, "(%s)" % ("THE POISONER!" if role == "poisoner" else Defs.role_name(StringName(role)).to_lower())],
				Ui.YELLOW)
	v.add_child(Ui.button("BACK", func() -> void: layer.queue_free(), Ui.MINT, 20, Vector2(0, 50)))
	Ui.pop_in(p)
