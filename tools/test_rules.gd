extends SceneTree
## Headless checks for TeaRules + BotBrain ("Murder at Teatime"):
##   godot --headless --script res://tools/test_rules.gd
## Unit checks for each rule, then all-bot matches (serve, sightings, items, toast, meeting
## claims, vote) that must end with winners. Prints the win balance per table size.

var failures := 0
var SIM_RULES := {} if OS.get_environment("NOROLES") == "" else ({"inspector": false, "physician": false} if OS.get_environment("NOROLES") == "1" else {"physician": false})


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
	_roles()
	_new_items()


## Tea leaves, a fresh cup, and the twists.
func _new_items() -> void:
	var I := Defs.Ingredient
	var IT := Defs.Item
	var r := TeaRules.new()
	r.setup(_players(4), {"items_per_round": 0, "inspector": false, "physician": false}, 21)
	r.start_round()
	var pz: int = r.poisoner_seats()[0]
	var v := (pz + 1) % 4
	r.pour(pz, (r.seats[pz]["hand"] as Array).find(I.POISON), v)
	var other := (pz + 2) % 4
	r.pour(other, 0, v)
	for s in 4:
		r.seats[s]["items"] = [IT.LEAVES, IT.FRESH]
	r.begin_items()
	check(r.choose_item(other, 0, [v]) == "", "read the leaves")
	check(r.choose_item(pz, 1, [v]) == "", "ring for a fresh cup")
	for s in 4:
		r.pass_turn(s)
	var n := -1
	var saved := false
	for st: Dictionary in r.resolve_items():
		for ev: Dictionary in st["private"]:
			if ev.get("type", "") == "leaves_result":
				n = int(ev["count"])
		for ev: Dictionary in st["public"]:
			if ev.get("type", "") == "moments":
				saved = true
	check(n == 2, "the leaves count the pours (%d)" % n)
	check(saved and (r.cups[r.cup_at[v]]["contents"] as Array).is_empty(), "a fresh cup takes the poison away")
	# Twists: never in round 1, then most rounds; a blackout means no glimpses.
	var seen := {}
	var t := TeaRules.new()
	t.setup(_players(6), {}, 22)
	t.start_round()
	check(t.twist == &"", "no twist in the first round")
	for k in 40:
		t.start_round()
		if t.twist != &"":
			seen[t.twist] = true
	check(seen.size() >= 4, "the twists come up (%d kinds)" % seen.size())
	t.twist = &"blackout"
	for s in t.alive_seats():
		t.seats[s]["served"] = (s + 1) % 6
	var sg := t.deal_sightings()
	var any := false
	for s: int in sg:
		if int(sg[s]["who"]) >= 0:
			any = true
	check(not any, "blackout: nobody glimpses")


## The Inspector and the Physician.
func _roles() -> void:
	var I := Defs.Ingredient
	var IT := Defs.Item
	var r := TeaRules.new()
	r.setup(_players(6), {"items_per_round": 1}, 11)
	var ins := -1
	var doc := -1
	for s in 6:
		if r.seats[s]["role"] == TeaRules.INSPECTOR:
			ins = s
		elif r.seats[s]["role"] == TeaRules.PHYSICIAN:
			doc = s
	check(ins >= 0 and doc >= 0 and ins != doc, "6 guests: an Inspector and a Physician")
	check(not r.is_poisoner(ins) and not r.is_poisoner(doc), "the roles are innocents")
	var r5 := TeaRules.new()
	r5.setup(_players(5), {}, 12)
	check(r5.has_role(TeaRules.INSPECTOR) and not r5.has_role(TeaRules.PHYSICIAN), "5 guests: Inspector only")
	var r4 := TeaRules.new()
	r4.setup(_players(4), {}, 13)
	check(not r4.has_role(TeaRules.INSPECTOR), "4 guests: no special roles")
	var off := TeaRules.new()
	off.setup(_players(6), {"inspector": false, "physician": false}, 14)
	check(not off.has_role(TeaRules.INSPECTOR) and not off.has_role(TeaRules.PHYSICIAN), "roles can be switched off")
	r.start_round()
	var pz: int = r.poisoner_seats()[0]
	check((r.seats[ins]["items"] as Array)[0] == IT.INSPECT and (r.seats[ins]["items"] as Array).size() == 2, "the Inspector gets INSPECT on top of an item")
	check((r.seats[doc]["items"] as Array)[0] == IT.PROTECT, "the Physician gets WATCH OVER")
	# The poisoner serves the guest the Physician will watch over.
	var victim := ins
	r.pour(pz, (r.seats[pz]["hand"] as Array).find(I.POISON), victim)
	for s in 6:
		if s != pz:
			var t := (s + 1) % 6
			if t == victim or t == s:
				t = (t + 1) % 6
			if t == s:
				t = (t + 1) % 6
			r.pour(s, (r.seats[s]["hand"] as Array).find(I.SUGAR) if (r.seats[s]["hand"] as Array).has(I.SUGAR) else 0, t)
	# An antidote would spoil the test: take them all out of the victim's cup.
	var vc: Dictionary = r.cups[r.cup_at[victim]]
	vc["contents"] = (vc["contents"] as Array).filter(func(c: Dictionary) -> bool: return c["k"] == I.POISON)
	r.begin_items()
	check(r.choose_item(ins, 0, [ins]) != "", "the Inspector can't inspect themselves")
	check(r.choose_item(ins, 0, [pz]) == "", "inspect the poisoner")
	check(not r.seats[ins]["item_done"], "the Inspector still has their item to play")
	check(r.choose_item(ins, 0, [pz]) != "", "one inspection a round")
	check(r.choose_item(doc, 0, [victim]) == "", "the Physician watches over the victim")
	for s in 6:
		r.pass_turn(s)
	var steps := r.resolve_items()
	var found := false
	for st: Dictionary in steps:
		if int(st["item"]) in [IT.INSPECT, IT.PROTECT]:
			check(st.get("secret", false) and (st["public"] as Array).is_empty(), "role cards are secret")
		for ev: Dictionary in st["private"]:
			if ev.get("type", "") == "inspect_result":
				found = bool(ev["guilty"]) and int(ev["who"]) == pz
	check(found, "the Inspector finds poison on the hands of the guest who poured it")
	var drinks := r.drink_all()
	var rev := false
	for d: Dictionary in drinks:
		if int(d["seat"]) == victim:
			rev = bool(d["revived"]) and not bool(d["died"])
	check(rev and r.is_alive(victim), "smelling salts: the watched guest survives the poison")
	check(r.seats[doc]["revives"] == 1, "the revive is counted")
	r.start_round()
	r.begin_items()
	check(r.choose_item(doc, 0, [victim]) != "", "not the same guest two rounds running")
	check(r.choose_item(doc, 0, [doc]) == "", "the Physician may watch over themselves")
	r.resolve_items()
	r.start_round()
	r.begin_items()
	check(r.choose_item(doc, 0, [doc]) != "", "...but only once")


func _simulate(n: int, count: int) -> void:
	var rounds_total := 0
	var guest_wins := 0
	var correct_ejects := 0
	var ejects := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	for game in count:
		var r := TeaRules.new()
		r.setup(_players(n), SIM_RULES, game * 7919 + n)
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
				var tries := 0
				while not r.seats[s]["item_done"] and tries < 4:
					tries += 1
					var choice := bots[s].choose_item(r.private_state(s), r.public_state())
					if choice.is_empty():
						r.pass_turn(s)
					else:
						var err := r.choose_item(s, choice["index"], choice["targets"])
						check(err == "", "bot item ok: %s" % err)
						if err != "":
							r.pass_turn(s)
				check(r.seats[s]["item_done"], "bot finished its items")
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
