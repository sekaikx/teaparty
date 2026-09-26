class_name ResultsScreen
extends Control
## After the last cup: who won and why, everyone's evening, and what you earned.

signal back_to_lobby
signal leave


func show_result(res: Dictionary, my_seat: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.hs.add_backdrop(self, 0.4)
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(620, 0)
	add_child(UiKit.center(p))
	var v := UiKit.vbox(8)
	p.add_child(v)
	var winners: Array = res.get("winners", [])
	var seats: Array = res.get("seats", [])
	var won := winners.has(my_seat)
	v.add_child(UiKit.title("You win!" if won else "The party is over", 40, UiKit.hs.good if won else Color()))
	v.add_child(UiKit.wrap(UiKit.label(String(res.get("reason", "")), 16, UiKit.hs.accent, &"serif", 600), 560))
	v.add_child(UiKit.hs.rule(4, 4))
	for i in seats.size():
		var s: Dictionary = seats[i]
		var h := UiKit.hbox(8)
		var crown := "* " if winners.has(i) else "   "
		var extra := ""
		if s.get("role", &"guest") == &"butler":
			extra = "  (the butler)"
		elif int(s.get("team", -1)) >= 0:
			extra = "  (%s)" % Defs.TEAM_NAMES[int(s["team"])]
		var nm := UiKit.label(crown + String(s["name"]) + extra + ("  - you" if i == my_seat else ""), 15, UiKit.hs.good if winners.has(i) else Color(), &"serif", 650)
		nm.custom_minimum_size.x = 300
		h.add_child(nm)
		var fate := "survived" if s["alive"] else "fell in round %d" % int(s["died_round"])
		h.add_child(UiKit.label(fate, 13, UiKit.hs.text_soft))
		h.add_child(UiKit.spacer(0, 0, true))
		h.add_child(UiKit.label("%d poisoned" % int(s["kills"]), 13, UiKit.hs.accent, &"sans", 800))
		v.add_child(h)
	var award: Dictionary = res.get("award", {})
	if not award.is_empty():
		v.add_child(UiKit.hs.rule(4, 4))
		var ah := UiKit.hbox(16)
		v.add_child(ah)
		ah.add_child(UiKit.label("+%d XP" % int(award["xp"]), 18, UiKit.hs.accent, &"serif", 700))
		UiKit.hs.coin_label(ah, int(award["coins"]), 18, 22)
		if int(award["levels"]) > 0:
			ah.add_child(UiKit.label("Level up! Now level %d" % int(award["level"]), 18, UiKit.hs.good, &"serif", 700))
			Sfx.play(&"fanfare")
		for t: String in award.get("titles", []):
			v.add_child(UiKit.label("New title: %s" % t, 15, UiKit.hs.good, &"serif", 650))
		for u: String in award.get("unlocks", []):
			v.add_child(UiKit.label("Unlocked - %s" % u, 15, UiKit.hs.good, &"serif", 650))
	var bh := UiKit.hbox(10)
	v.add_child(bh)
	bh.add_child(UiKit.button("Leave", func() -> void: leave.emit()))
	bh.add_child(UiKit.spacer(0, 0, true))
	bh.add_child(UiKit.button("Back to the lobby", func() -> void: back_to_lobby.emit(), true))
	UiKit.fade_in(self, 0.5)
	Sfx.play(&"fanfare" if won else &"sting", -2.0)
