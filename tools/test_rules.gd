extends SceneTree
## Headless checks for TeaRules + BotBrain ("Murder at Teatime"):
##   godot --headless --script res://tools/test_rules.gd
## Unit checks for each rule, then all-bot matches (serve, sightings, items, toast, meeting
## claims, vote) that must end with winners. Prints the win balance per table size.

var failures := 0


func _init() -> void:
	_unit()
	for n in [4, 5, 6, 7, 8]:
		_simulate(n, 300)
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
	r.setup(_players(5), {"items_per_round": 0}, 1)
	check(r.poisoner_seats().size() == 1, "one poisoner at 5")
	var r8 := TeaRules.new()
	r8.setup(_players(8), {}, 2)
	check(r8.poisoner_seats().size() == 2, "two poisoners at 8")
	var pz: int = r.poisoner_seats()[0]
	r.start_round()
	check((r.seats[pz]["hand"] as Array).has(I.POISON), "poisoner holds poison")
	var antis := 0
	for s in 5:
		if s != pz:
			check(not (r.seats[s]["hand"] as Array).has(I.POISON), "innocents hold no poison")
			if (r.seats[s]["hand"] as Array).has(I.ANTIDOTE):
				antis += 1
	check(antis == 1, "exactly one antidote")
	var victim := (pz + 1) % 5
	check(not r.pour(pz, 0, pz), "can't pour into your own cup")
	var pi := (r.seats[pz]["hand"] as Array).find(I.POISON)
	check(r.pour(pz, pi, victim), "poisoner serves the victim")
	check(not r.pour(pz, 0, victim), "one pour each")
	for s in 5:
		if s == pz:
			continue
		# Everyone else pours plain/sugar/antidote somewhere that isn't the victim.
		var t := s
		while t == s or t == victim:
			t = (t + 1) % 5
		check(r.pour(s, 0, t), "innocent serves %d -> %d" % [s, t])
	check(r.all_poured(), "all poured")
	r.rules["glimpse_chance"] = 1.0
	var sg := r.deal_sightings()
	check(sg.size() == 5, "everyone glimpses one pour")
	for s: int in sg:
		check(int(sg[s]["who"]) != s, "you don't glimpse yourself")
		check(int(sg[s]["into"]) == r.pour_target(int(sg[s]["who"])), "sightings are true")
	check(r.smell(victim) in ["poison", "sweet"], "the victim's cup smells")
	r.drink_all()
	check(not r.is_alive(victim), "the victim fell")
	check(r.seats[pz]["kills"] == 1, "the poisoner got the kill")
	var pub := r.public_state()
	check(pub["seats"][pz]["role"] == &"", "a living poisoner's role stays secret")
	check(pub["seats"][victim]["role"] == &"guest", "a dead guest's role is shown")
	var rv := r.reveal()
	check(rv.size() >= 1 and not str(rv).contains("\"by\""), "the reveal names nobody")
	r.begin_vote()
	for s in r.alive_seats():
		check(r.vote(s, pz if s != pz else -1), "vote %d" % s)
	check(r.votes_done(), "votes done")
	var t := r.tally()
	check(int(t["ejected"]) == pz and t["role"] == TeaRules.POISONER, "the poisoner is thrown out")
	var w := r.check_winner()
	check(w["over"] and not (w["winners"] as Array).has(pz), "guests win")
	# Ties and skips throw nobody out.
	var r2 := TeaRules.new()
	r2.setup(_players(4), {}, 3)
	r2.start_round()
	r2.begin_vote()
	r2.vote(0, 1)
	r2.vote(1, 0)
	r2.vote(2, -1)
	r2.vote(3, -1)
	check(int(r2.tally()["ejected"]) == -1, "tie or skip: nobody out")
	check(not TeaRules.lethal([{"k": I.POISON, "by": 0}, {"k": I.ANTIDOTE, "by": 1}]), "antidote cancels")
	var r3 := TeaRules.new()
	r3.setup(_players(4), {"items_per_round": 0}, 4)
	r3.start_round()
	var p3: int = r3.poisoner_seats()[0]
	var v3 := (p3 + 1) % 4
	r3.pour(p3, (r3.seats[p3]["hand"] as Array).find(I.POISON), v3)
	check(r3.smell(v3) == "poison", "poison smell")
	check(r3.spill(v3, p3), "the spill knocked away a deadly cup")
	check(not TeaRules.lethal(r3.cups[r3.cup_at[v3]]["contents"]), "a spilled cup is safe")
	var r4 := TeaRules.new()
	r4.setup(_players(4), {}, 5)
	var p4: int = r4.poisoner_seats()[0]
	var n := 0
	for s in 4:
		if s != p4 and n < 2:
			r4.seats[s]["alive"] = false
			n += 1
	var w4 := r4.check_winner()
	check(w4["over"] and (w4["winners"] as Array) == [p4], "poisoner wins at 1 v 1")


func _simulate(n: int, count: int) -> void:
	var rounds_total := 0
	var guest_wins := 0
	var correct_ejects := 0
	var ejects := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	for game in count:
		var r := TeaRules.new()
		r.setup(_players(n), {}, game * 7919 + n)
		var bots: Array[BotBrain] = []
		for s in n:
			bots.append(BotBrain.new(s, game * 31 + s))
		var result := {}
		var guard := 0
		while guard < 20 and result.is_empty():
			guard += 1
			r.start_round()
			var pub := r.public_state()
			for s in r.alive_seats():
				bots[s].new_round(pub)
			for s in r.alive_seats():
				var sv := bots[s].choose_serve(r.private_state(s), pub)
				check(not sv.is_empty() and r.pour(s, sv["index"], sv["target"]), "bot serve")
			r.deal_sightings()
			r.begin_items()
			for s in r.alive_seats():
				var choice := bots[s].choose_item(r.private_state(s), r.public_state())
				if choice.is_empty():
					r.pass_turn(s)
				else:
					var err := r.choose_item(s, choice["index"], choice["targets"])
					check(err == "", "bot item ok: %s" % err)
					if err != "":
						r.pass_turn(s)
			for step: Dictionary in r.resolve_items():
				for ev: Dictionary in step["private"]:
					bots[int(step["seat"])].on_private_event(ev, r.public_state())
			for s in r.alive_seats():
				if bots[s].fears_own_cup(r.public_state()) and rng.randf() < 0.4:
					r.spill(s, s)
			r.drink_all()
			var w := r.check_winner()
			if w["over"]:
				result = w
				break
			var rv := r.reveal()
			for s in r.seats.size():
				bots[s].on_reveal(rv)
			for line in 5:
				for s in r.alive_seats():
					var c := bots[s].next_claim(r.private_state(s), r.public_state())
					if c.is_empty():
						continue
					c["seat"] = s
					for o in r.seats.size():
						bots[o].hear(c)
			r.begin_vote()
			for s in r.alive_seats():
				r.vote(s, bots[s].choose_vote(r.public_state()))
			var t := r.tally()
			if int(t["ejected"]) >= 0:
				ejects += 1
				if t["role"] == TeaRules.POISONER:
					correct_ejects += 1
			w = r.check_winner(r.round_no >= int(r.rules["max_rounds"]))
			if w["over"]:
				result = w
		rounds_total += r.round_no
		check(not result.is_empty(), "%d-guest game %d ended" % [n, game])
		var winners: Array = result.get("winners", [])
		check(not winners.is_empty(), "game %d has winners" % game)
		if not winners.is_empty() and not r.is_poisoner(int(winners[0])):
			guest_wins += 1
	print("%d guests: %d games, avg %.1f rounds, guests win %d%%, ejects hit the poisoner %d%%" % [n, count,
		float(rounds_total) / count, 100 * guest_wins / count, 100 * correct_ejects / maxi(ejects, 1)])
