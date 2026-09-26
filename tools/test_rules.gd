extends SceneTree
## Headless checks for TeaRules + BotBrain:
##   godot --headless --script res://tools/test_rules.gd
## Unit checks for each rule, then 300 all-bot matches per mode that must end with winners.

var failures := 0


func _init() -> void:
	_unit()
	for m: StringName in [&"classic", &"teams", &"butler"]:
		for n in [3, 4, 6, 8]:
			_simulate(m, n, 100)
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		push_error("FAIL: " + what)


func _players(n: int) -> Array:
	var out := []
	for i in n:
		out.append({"id": 100 + i, "name": "P%d" % i, "bot": true})
	return out


func _unit() -> void:
	var I := Defs.Ingredient
	var r := TeaRules.new()
	r.setup(_players(4), {"items_per_round": 0}, 1)
	r.start_round()
	check(r.alive_seats().size() == 4, "4 alive")
	check(r.pour_target(0) == 1 and r.pour_target(3) == 0, "pour clockwise")
	# Force hands.
	r.seats[0]["hand"] = [I.POISON, I.NOTHING, I.SUGAR]
	r.seats[1]["hand"] = [I.ANTIDOTE, I.NOTHING, I.NOTHING]
	r.seats[2]["hand"] = [I.POISON, I.NOTHING, I.NOTHING]
	r.seats[3]["hand"] = [I.NOTHING, I.NOTHING, I.NOTHING]
	check(r.pour(0, 0), "pour ok")
	check(not r.pour(0, 0), "no double pour")
	r.pour(1, 1)   # nothing into 2
	r.pour(2, 0)   # poison into 3
	r.pour(3, 0)   # nothing into 0
	check(r.all_poured(), "all poured")
	check(r.smell(1) == "poison", "cup 1 smells of poison")
	check(r.smell(0) == "clean", "cup 0 clean")
	# Swap 1 <-> 0 by hand, then the table drinks.
	for s in 4:
		r.seats[s]["items"] = []
	r.seats[0]["items"] = [Defs.Item.SWAP]
	r.begin_items()
	check(r.choose_item(0, 0, [0, 1]) == "", "swap locked in")
	check(r.choose_item(0, 0, [0, 1]) != "", "no double pick")
	check(r.items_done(), "everyone else had no items")
	var steps := r.resolve_items()
	check(steps.size() == 1, "one step")
	check(r.smell(0) == "poison" and r.smell(1) == "clean", "cups moved")
	var drinks := r.drink_all()
	check(drinks.size() == 4, "4 drinks")
	check(not r.is_alive(0) and not r.is_alive(3) and r.is_alive(1) and r.is_alive(2), "0 and 3 fell")
	check(r.seats[0]["kills"] == 0, "no self-kill credit")
	check(r.seats[2]["kills"] == 1, "seat 2 poisoned seat 3")
	check(r.pour_target(1) == 2 and r.pour_target(2) == 1, "pour skips the dead")
	var w := r.check_winner()
	check(not w["over"], "two alive, not over")

	# Antidote cancels one poison; sugar masks the smell.
	check(not TeaRules.lethal([{"k": I.POISON, "by": 0}, {"k": I.ANTIDOTE, "by": 1}]), "antidote cancels")
	check(TeaRules.lethal([{"k": I.POISON, "by": 0}, {"k": I.POISON, "by": 1}, {"k": I.ANTIDOTE, "by": 2}]), "two poisons beat one antidote")
	var r2 := TeaRules.new()
	r2.setup(_players(3), {"items_per_round": 0}, 2)
	r2.start_round()
	r2.seats[0]["hand"] = [I.POISON]
	r2.seats[1]["hand"] = [I.SUGAR]
	r2.seats[2]["hand"] = [I.SUGAR]
	r2.pour(0, 0)
	r2.pour(2, 0)   # sugar into seat 0
	check(r2.smell(1) == "poison", "poison smell")
	(r2.cups[r2.cup_at[1]]["contents"] as Array).append({"k": I.SUGAR, "by": 2})
	check(r2.smell(1) == "sweet", "sugar masks")

	# Toast: target drinks now, turn passes, a drunk cup is empty.
	var r3 := TeaRules.new()
	r3.setup(_players(3), {"items_per_round": 0}, 3)
	r3.start_round()
	r3.seats[0]["hand"] = [I.POISON]
	r3.seats[1]["hand"] = [I.NOTHING]
	r3.seats[2]["hand"] = [I.NOTHING]
	for s in 3:
		r3.pour(s, 0)
	r3.seats[0]["items"] = [Defs.Item.TOAST]
	r3.begin_items()
	check(r3.choose_item(0, 0, [0]) != "", "cannot toast yourself")
	check(r3.choose_item(0, 0, [1]) == "", "toast ok")
	r3.resolve_items()
	check(not r3.is_alive(1), "toasted guest drank poison")
	var bl := TeaRules.blame([{"k": I.POISON, "by": 0}], {})
	check((bl["poisoners"] as Array) == [0], "blame names the poisoner")
	check(r3.check_winner()["over"] == false, "two alive")

	# Laced pot from round N puts poison in every cup.
	var r4 := TeaRules.new()
	r4.setup(_players(4), {"laced_round": 1}, 4)
	r4.start_round()
	check(r4.laced and r4.smell(0) == "poison", "laced pot")

	# Ghost rattles.
	check(r.rattle(3, 1) == false, "no rattles before the next round")
	r.start_round()
	check(r.rattle(3, 1), "ghost rattles")
	check(not r.rattle(1, 2), "the living cannot rattle")
	check(not r.rattle(3, 0), "cannot rattle a dead guest's cup")
	var pv := r.private_state(3)
	check(pv.has("ghost_view"), "ghosts see cups")
	check(not r.private_state(1).has("ghost_view"), "the living do not")

	# Butler: exists, gets poison, can spike once.
	var r5 := TeaRules.new()
	r5.setup(_players(5), {"mode": &"butler"}, 5)
	r5.start_round()
	var b := r5.butler_seat()
	check(not r5.spike(b, (b + 1) % 5), "no spike in round 1")
	r5.start_round()
	check(b >= 0, "a butler")
	check((r5.seats[b]["hand"] as Array).has(I.POISON), "butler holds poison")
	var victim := (b + 2) % 5
	check(r5.spike(b, victim), "spike")
	check(not r5.spike(b, victim), "one spike a round")
	check(r5.smell(victim) in ["poison", "sweet"], "spiked cup")

	# Teams alternate.
	var r6 := TeaRules.new()
	r6.setup(_players(4), {"mode": &"teams"}, 6)
	check(r6.seats[0]["team"] == 0 and r6.seats[1]["team"] == 1, "teams alternate")


func _simulate(m: StringName, n: int, count: int) -> void:
	var rounds_total := 0
	var butler_wins := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 101
	for game in count:
		var r := TeaRules.new()
		r.setup(_players(n), {"mode": m}, game * 7919 + n)
		var bots: Array[BotBrain] = []
		for s in n:
			bots.append(BotBrain.new(s, game * 31 + s))
		var result := {}
		var guard := 0
		while guard < 40:
			guard += 1
			r.start_round()
			var pub := r.public_state()
			for s in r.alive_seats():
				bots[s].new_round(pub)
			for s in r.alive_seats():
				var priv := r.private_state(s)
				var idx := bots[s].choose_pour(priv, pub)
				check(r.pour(s, idx), "bot pour")
				var sp := bots[s].choose_spike(r.private_state(s), pub)
				if sp >= 0:
					r.spike(s, sp)
			check(r.all_poured(), "all poured")
			r.begin_items()
			var over := false
			for s in r.alive_seats():
				if r.seats[s]["item_done"]:
					continue
				var choice := bots[s].choose_item(r.private_state(s), r.public_state())
				if choice.is_empty():
					r.pass_turn(s)
				else:
					var err := r.choose_item(s, choice["index"], choice["targets"])
					check(err == "", "bot item ok: %s" % err)
					if err != "":
						r.pass_turn(s)
			check(r.items_done(), "all picked")
			for step: Dictionary in r.resolve_items():
				for ev: Dictionary in step["private"]:
					bots[int(step["seat"])].on_private_event(ev, r.public_state())
			# Some cakes land on cups.
			if rng.randf() < 0.3 and not r.alive_seats().is_empty():
				var al := r.alive_seats()
				r.spill(al[rng.randi_range(0, al.size() - 1)], al[0])
			var w := r.check_winner()
			if w["over"]:
				result = w
				over = true
			if over:
				break
			r.drink_all()
			var final_round := r.round_no >= int(r.rules["max_rounds"])
			var w2 := r.check_winner(final_round)
			if w2["over"]:
				result = w2
				break
		rounds_total += r.round_no
		if m == &"butler" and (result.get("winners", []) as Array).has(r.butler_seat()):
			butler_wins += 1
		check(not result.is_empty(), "%s/%d game %d ended" % [m, n, game])
		check(not (result.get("winners", []) as Array).is_empty(), "%s/%d game %d has winners (%s)" % [m, n, game, result.get("reason", "")])
	print("%s x%d: %d games, avg %.1f rounds%s" % [m, n, count, float(rounds_total) / count, (", butler won %d" % butler_wins) if m == &"butler" else ""])
