class_name TeaRules
extends RefCounted
## The whole game as pure data: seats, hands, cups, items and win conditions. No nodes, no
## networking; Session (the host) drives it and tools/test_rules.gd exercises it headless.
##
## Seats are fixed places around the table (dead guests keep their seat and become ghosts).
## Cups are objects that move: `cup_at[seat]` is the cup in front of a seat, so a swap just
## exchanges two entries. Each cup holds a list of {k: Ingredient, by: seat} (by -1 = the laced pot).
## A drinker collapses when their cup holds more poison than antidote.

const I := Defs.Ingredient
const IT := Defs.Item

var rng := RandomNumberGenerator.new()
var rules: Dictionary = Defs.default_rules()
var seats: Array[Dictionary] = []
var cups: Dictionary = {}
var cup_at: Array[int] = []
var round_no := 0
var laced := false
## Drinks this round in order: {seat, cup, contents, died, toast}.
var drinks: Array[Dictionary] = []
## Seats that fell in the most recent drinking (a toast or the table drink).
var fallen_last: Array[int] = []


func setup(players: Array, p_rules: Dictionary, seed_value: int) -> void:
	rng.seed = seed_value
	rules = Defs.default_rules()
	for k: String in p_rules:
		rules[k] = p_rules[k]
	seats.clear()
	cups.clear()
	cup_at.clear()
	round_no = 0
	for i in players.size():
		var p: Dictionary = players[i]
		seats.append({
			"id": int(p.get("id", i + 1)), "name": String(p.get("name", "Guest")),
			"bot": bool(p.get("bot", false)), "cos": p.get("cos", {}), "level": int(p.get("level", 1)),
			"alive": true, "team": (i % 2) if mode() == &"teams" else -1, "role": &"guest",
			"hand": [], "items": [], "poured": false, "dropped": -1, "spiked": false,
			"item_done": false, "ready": false, "rattles": 0, "died_round": -1,
			"kills": 0, "rounds_survived": 0, "sniffs": 0, "toasts": 0, "swaps": 0, "peeks": 0,
			"rattles_used": 0,
		})
		cups[i] = {"id": i, "owner": i, "contents": [], "tea": false, "drunk": false}
		cup_at.append(i)
	if mode() == &"butler" and seats.size() >= 3:
		seats[rng.randi_range(0, seats.size() - 1)]["role"] = &"butler"
	# Starting items.
	for s in seats:
		for n in maxi(1, int(rules["items_per_round"])):
			_give_item(s)


func mode() -> StringName:
	return StringName(rules.get("mode", &"classic"))


func seat_count() -> int:
	return seats.size()


func alive_seats() -> Array[int]:
	var out: Array[int] = []
	for i in seats.size():
		if seats[i]["alive"]:
			out.append(i)
	return out


func is_alive(seat: int) -> bool:
	return seat >= 0 and seat < seats.size() and bool(seats[seat]["alive"])


func seat_of_id(id: int) -> int:
	for i in seats.size():
		if int(seats[i]["id"]) == id:
			return i
	return -1


func butler_seat() -> int:
	for i in seats.size():
		if seats[i]["role"] == &"butler":
			return i
	return -1


# ---------------------------------------------------------------- rounds and dealing

func start_round() -> void:
	round_no += 1
	laced = round_no >= int(rules["laced_round"])
	drinks.clear()
	fallen_last.clear()
	for i in seats.size():
		var s := seats[i]
		s["hand"] = []
		s["poured"] = false
		s["dropped"] = -1
		s["spiked"] = false
		s["item_done"] = false
		s["ready"] = false
		s["rattles"] = int(rules["ghost_rattles"]) if not s["alive"] else 0
	# Fresh cups in front of every living guest; the ones on the table stay where they were.
	for seat in seats.size():
		var cup: Dictionary = cups[cup_at[seat]]
		cup["contents"] = [{"k": I.POISON, "by": -1}] if laced and seats[seat]["alive"] else []
		cup["tea"] = false
		cup["drunk"] = not seats[seat]["alive"]
		cup["swapped_by"] = -1
		cup["spilled"] = false
		cup["spilled_by"] = -1
	var alive := alive_seats()
	var hand_size := clampi(int(rules["hand_size"]), 1, 5)
	var deck := build_deck(alive.size() * hand_size)
	for seat in alive:
		var hand: Array = []
		for n in hand_size:
			hand.append(deck.pop_back())
		seats[seat]["hand"] = hand
	var b := butler_seat()
	if b >= 0 and is_alive(b) and not (seats[b]["hand"] as Array).has(I.POISON):
		(seats[b]["hand"] as Array)[0] = I.POISON
	if round_no > 1:
		for seat in alive:
			for n in int(rules["items_per_round"]):
				_give_item(seats[seat])


## The ingredient deck for one round: poison rises each round, antidotes thin out.
func build_deck(n: int) -> Array:
	var scale := float(rules.get("poison_scale", 1.0))
	var poison := maxi(1, roundi(n * clampf((0.12 + 0.08 * (round_no - 1)) * scale, 0.05, 0.65)))
	var antidote := maxi(1, roundi(n * clampf(0.24 - 0.025 * (round_no - 1), 0.08, 0.24)))
	var sugar := roundi(n * 0.2)
	var deck: Array = []
	for k in poison:
		deck.append(I.POISON)
	for k in antidote:
		deck.append(I.ANTIDOTE)
	for k in sugar:
		deck.append(I.SUGAR)
	while deck.size() < n:
		deck.append(I.NOTHING)
	deck.resize(n)
	_shuffle(deck)
	return deck


func _give_item(s: Dictionary) -> void:
	var enabled: Array = rules.get("items_enabled", [])
	if enabled.is_empty():
		return
	var items: Array = s["items"]
	if items.size() >= int(rules["max_items"]):
		return
	items.append(int(enabled[rng.randi_range(0, enabled.size() - 1)]))


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


# ---------------------------------------------------------------- pour

## The next living guest clockwise: who `seat` pours for.
func pour_target(seat: int) -> int:
	var n := seats.size()
	for step in range(1, n):
		var s := (seat + step) % n
		if seats[s]["alive"]:
			return s
	return seat


## Pour tea for your neighbour and drop the card at `card_index` of your hand into their cup.
func pour(seat: int, card_index: int) -> bool:
	if not is_alive(seat) or seats[seat]["poured"]:
		return false
	var hand: Array = seats[seat]["hand"]
	if card_index < 0 or card_index >= hand.size():
		return false
	var k: int = hand[card_index]
	hand.remove_at(card_index)
	var target := pour_target(seat)
	var cup: Dictionary = cups[cup_at[target]]
	cup["tea"] = true
	(cup["contents"] as Array).append({"k": k, "by": seat})
	seats[seat]["poured"] = true
	seats[seat]["dropped"] = k
	return true


## Out of time: the card is picked for you.
func auto_pour(seat: int) -> int:
	var hand: Array = seats[seat]["hand"]
	var idx := rng.randi_range(0, hand.size() - 1) if not hand.is_empty() else -1
	if idx < 0:
		seats[seat]["poured"] = true
		cups[cup_at[pour_target(seat)]]["tea"] = true
		return I.NOTHING
	var k: int = hand[idx]
	pour(seat, idx)
	return k


## The butler's extra poison, into any other living guest's cup, once per round.
func spike(seat: int, target: int) -> bool:
	if seats[seat]["role"] != &"butler" or seats[seat]["spiked"] or not is_alive(seat) or round_no < 2:
		return false
	if not is_alive(target) or target == seat:
		return false
	(cups[cup_at[target]]["contents"] as Array).append({"k": I.POISON, "by": seat, "spike": true})
	seats[seat]["spiked"] = true
	return true


func all_poured() -> bool:
	for seat in alive_seats():
		if not seats[seat]["poured"]:
			return false
	return true


# ---------------------------------------------------------------- items (everyone at once)
# Everybody picks an item and its targets during the same short window; then they all play out
# in a fixed order that anyone can follow: sniffs and peeks first (information), then swaps (the
# cups move), then toasts (the drama). Within each group, seat order rotates every round.

const ITEM_ORDER := [Defs.Item.SNIFF, Defs.Item.PEEK, Defs.Item.SWAP, Defs.Item.TOAST]

## seat -> {"index": item index, "item": item, "targets": Array} or {} for a pass.
var picks: Dictionary = {}


func begin_items() -> void:
	picks.clear()
	for seat in alive_seats():
		seats[seat]["item_done"] = (seats[seat]["items"] as Array).is_empty()
		if seats[seat]["item_done"]:
			picks[seat] = {}


func items_done() -> bool:
	for seat in alive_seats():
		if not seats[seat]["item_done"]:
			return false
	return true


func pass_turn(seat: int) -> bool:
	if not is_alive(seat) or seats[seat]["item_done"]:
		return false
	seats[seat]["item_done"] = true
	picks[seat] = {}
	return true


## Validates targets for an item (seat indices). Returns "" when fine, else the reason.
func item_error(seat: int, item: int, targets: Array) -> String:
	var need: int = Defs.ITEMS[item]["targets"]
	if targets.size() != need:
		return "Pick %d target%s." % [need, "s" if need > 1 else ""]
	for t: int in targets:
		if not is_alive(t):
			return "Only living guests' cups."
	match item:
		IT.SWAP:
			if targets[0] == targets[1]:
				return "Pick two different cups."
		IT.TOAST, IT.PEEK:
			if targets[0] == seat:
				return "Pick another guest."
	return ""


## Lock in an item for this round's items phase. Returns "" or the reason it was refused.
func choose_item(seat: int, item_index: int, targets: Array) -> String:
	if not is_alive(seat):
		return "Ghosts can't use items."
	if seats[seat]["item_done"]:
		return "You've already picked."
	var items: Array = seats[seat]["items"]
	if item_index < 0 or item_index >= items.size():
		return "No such item."
	var item: int = items[item_index]
	var err := item_error(seat, item, targets)
	if err != "":
		return err
	picks[seat] = {"index": item_index, "item": item, "targets": targets.duplicate()}
	seats[seat]["item_done"] = true
	return ""


## Plays every locked-in item in order. Returns steps: {seat, item, public: [...], private: [...]}.
func resolve_items() -> Array:
	var steps: Array = []
	var alive := alive_seats()
	if alive.is_empty():
		return steps
	var offset := (round_no - 1) % alive.size()
	var order: Array[int] = []
	for i in alive.size():
		order.append(alive[(i + offset) % alive.size()])
	fallen_last.clear()
	for kind: int in ITEM_ORDER:
		for seat in order:
			var pk: Dictionary = picks.get(seat, {})
			if pk.is_empty() or int(pk["item"]) != kind:
				continue
			var step := {"seat": seat, "item": kind, "public": [], "private": []}
			steps.append(step)
			if not is_alive(seat):
				step["public"].append({"type": "note", "text": "%s's %s fizzles (they're dead)." % [seats[seat]["name"], Defs.item_name(kind)]})
				continue
			var targets: Array = pk["targets"]
			if item_error(seat, kind, targets) != "":
				step["public"].append({"type": "note", "text": "%s's %s fizzles." % [seats[seat]["name"], Defs.item_name(kind)]})
				_remove_item(seat, kind)
				continue
			_remove_item(seat, kind)
			match kind:
				IT.SWAP:
					var a: int = targets[0]
					var b: int = targets[1]
					var ca := cup_at[a]
					cup_at[a] = cup_at[b]
					cup_at[b] = ca
					cups[cup_at[a]]["swapped_by"] = seat
					cups[cup_at[b]]["swapped_by"] = seat
					seats[seat]["swaps"] += 1
					step["public"].append({"type": "swap", "seat": seat, "a": a, "b": b})
				IT.SNIFF:
					var t: int = targets[0]
					seats[seat]["sniffs"] += 1
					step["public"].append({"type": "sniff", "seat": seat, "target": t})
					step["private"].append({"type": "sniff_result", "target": t, "smell": smell(t)})
				IT.PEEK:
					var t: int = targets[0]
					seats[seat]["peeks"] += 1
					step["public"].append({"type": "peek", "seat": seat, "target": t})
					step["private"].append({"type": "peek_result", "target": t,
						"hand": (seats[t]["hand"] as Array).duplicate(), "items": (seats[t]["items"] as Array).duplicate()})
				IT.TOAST:
					var t: int = targets[0]
					seats[seat]["toasts"] += 1
					step["public"].append({"type": "toast", "seat": seat, "target": t})
					step["public"].append(drink(t, true))
	picks.clear()
	return steps


func _remove_item(seat: int, kind: int) -> void:
	var items: Array = seats[seat]["items"]
	var i := items.find(kind)
	if i >= 0:
		items.remove_at(i)


## Knocked over (a cake, a clumsy fall): the cup is emptied. An empty cup is safe to drink.
func spill(seat: int, by: int = -1) -> bool:
	if seat < 0 or seat >= cup_at.size() or not is_alive(seat):
		return false
	var cup: Dictionary = cups[cup_at[seat]]
	if cup["drunk"]:
		return false
	var was_lethal := lethal(cup["contents"])
	cup["contents"] = []
	cup["tea"] = false
	cup["spilled"] = true
	cup["spilled_by"] = by
	return was_lethal


## What a sniff tells: "sweet" (sugar masks it), "poison" or "clean". Antidotes do not smell.
func smell(seat: int) -> String:
	var contents: Array = cups[cup_at[seat]]["contents"]
	var has_poison := false
	for c: Dictionary in contents:
		if c["k"] == I.SUGAR:
			return "sweet"
		if c["k"] == I.POISON:
			has_poison = true
	return "poison" if has_poison else "clean"


## Ghosts rattle a living guest's cup (a limited number of times per round).
func rattle(ghost: int, target: int) -> bool:
	if ghost < 0 or ghost >= seats.size() or seats[ghost]["alive"] or int(seats[ghost]["rattles"]) <= 0:
		return false
	if not is_alive(target):
		return false
	seats[ghost]["rattles"] -= 1
	seats[ghost]["rattles_used"] += 1
	return true


# ---------------------------------------------------------------- drinking

static func lethal(contents: Array) -> bool:
	var p := 0
	var a := 0
	for c: Dictionary in contents:
		if c["k"] == I.POISON:
			p += 1
		elif c["k"] == I.ANTIDOTE:
			a += 1
	return p > a


## The seat drinks the cup in front of it. Returns the public drink event.
func drink(seat: int, toast: bool = false) -> Dictionary:
	var cup: Dictionary = cups[cup_at[seat]]
	var contents: Array = (cup["contents"] as Array).duplicate(true)
	var died := false
	if not cup["drunk"]:
		died = lethal(contents)
		cup["drunk"] = true
	else:
		contents = []
	var ev := {"type": "drink", "seat": seat, "cup": cup_at[seat], "contents": contents, "died": died, "toast": toast,
		"blame": blame(contents, cup)}
	drinks.append(ev)
	if died:
		_kill(seat, contents)
	return ev


## Everyone still at the table drinks at once.
func drink_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var alive := alive_seats()
	fallen_last.clear()
	# Resolve simultaneously: decide deaths first, then apply.
	for seat in alive:
		var cup: Dictionary = cups[cup_at[seat]]
		var contents: Array = (cup["contents"] as Array).duplicate(true) if not cup["drunk"] else []
		out.append({"type": "drink", "seat": seat, "cup": cup_at[seat], "contents": contents, "died": lethal(contents), "toast": false,
			"blame": blame(contents, cup)})
		cup["drunk"] = true
	for ev in out:
		drinks.append(ev)
		if ev["died"]:
			_kill(ev["seat"], ev["contents"])
	for seat in alive_seats():
		seats[seat]["rounds_survived"] += 1
	return out


func _kill(seat: int, contents: Array) -> void:
	seats[seat]["alive"] = false
	seats[seat]["died_round"] = round_no
	fallen_last.append(seat)
	for c: Dictionary in contents:
		var by: int = c["by"]
		if c["k"] == I.POISON and by >= 0 and by != seat:
			seats[by]["kills"] += 1


## Who's to blame for a cup: {"poisoners": [seats] (-1 = the laced pot), "swapped_by": seat or -1,
## "spilled_by": seat or -1}.
static func blame(contents: Array, cup: Dictionary) -> Dictionary:
	var by: Array = []
	for c: Dictionary in contents:
		var who := -2 if c.get("spike", false) else int(c["by"])
		if c["k"] == Defs.Ingredient.POISON and not by.has(who):
			by.append(who)
	return {"poisoners": by, "swapped_by": int(cup.get("swapped_by", -1)), "spilled": bool(cup.get("spilled", false)),
		"spilled_by": int(cup.get("spilled_by", -1))}


## The reveal: what was in every cup that was drunk this round.
func reveal() -> Array:
	var out: Array = []
	for d in drinks:
		var kinds: Array = []
		for c: Dictionary in d["contents"]:
			kinds.append(c["k"])
		out.append({"seat": d["seat"], "kinds": kinds, "died": d["died"], "toast": d["toast"], "blame": d.get("blame", {})})
	return out


# ---------------------------------------------------------------- winning

## {over, winners: Array[int] seats, reason}
func check_winner(final_round_reached: bool = false) -> Dictionary:
	var alive := alive_seats()
	var res := {"over": false, "winners": [], "reason": ""}
	match mode():
		&"teams":
			var counts := [0, 0]
			for s in alive:
				counts[seats[s]["team"]] += 1
			if counts[0] == 0 or counts[1] == 0 or final_round_reached:
				res["over"] = true
				var team := -1
				if counts[0] > counts[1]:
					team = 0
				elif counts[1] > counts[0]:
					team = 1
				if team < 0 and alive.is_empty():
					# Both teams fell together: the team with the most last-fallen shares.
					for s in fallen_last:
						res["winners"].append(s)
					res["reason"] = "Both teams fell at once. A bitter draw."
				elif team < 0:
					res["winners"] = alive
					res["reason"] = "Time's up: the teams share the pot."
				else:
					for i in seats.size():
						if seats[i]["team"] == team:
							res["winners"].append(i)
					res["reason"] = "Team %s holds the table." % Defs.TEAM_NAMES[team]
		&"butler":
			var b := butler_seat()
			if b >= 0 and not is_alive(b):
				res["over"] = true
				for i in seats.size():
					if i != b:
						res["winners"].append(i)
				res["reason"] = "The butler did it, and the butler is dead. The guests win."
			elif b >= 0 and (alive.size() <= (2 if seats.size() >= 5 else 1) or final_round_reached):
				res["over"] = true
				res["winners"] = [b]
				res["reason"] = "Only the butler is left to clear the table. The butler wins."
		_:
			if alive.size() <= 1 or final_round_reached:
				res["over"] = true
				if alive.size() == 1:
					res["winners"] = alive
					res["reason"] = "%s is the last guest standing." % seats[alive[0]]["name"]
				elif alive.is_empty():
					res["winners"] = fallen_last.duplicate()
					res["reason"] = "Nobody survived. The last to fall share the win."
				else:
					res["winners"] = alive
					res["reason"] = "The tea ran out. The survivors share the win."
	return res


# ---------------------------------------------------------------- views

## What everyone may see.
func public_state() -> Dictionary:
	var ps: Array = []
	for i in seats.size():
		var s := seats[i]
		ps.append({
			"id": s["id"], "name": s["name"], "bot": s["bot"], "cos": s["cos"], "level": s["level"],
			"alive": s["alive"], "team": s["team"], "poured": s["poured"], "item_done": s["item_done"],
			"ready": s["ready"], "rattles": s["rattles"], "hand_count": (s["hand"] as Array).size(),
			"item_count": (s["items"] as Array).size(), "pour_target": pour_target(i) if s["alive"] else -1,
		})
	var cs: Array = []
	for seat in cup_at.size():
		var c: Dictionary = cups[cup_at[seat]]
		cs.append({"id": c["id"], "owner": c["owner"], "tea": c["tea"], "drunk": c["drunk"], "count": (c["contents"] as Array).size(),
			"spilled": bool(c.get("spilled", false))})
	return {"round": round_no, "laced": laced, "seats": ps, "cups": cs}


## What one seat may see on top of the public state.
func private_state(seat: int) -> Dictionary:
	if seat < 0 or seat >= seats.size():
		return {}
	var s := seats[seat]
	var out := {
		"seat": seat, "hand": (s["hand"] as Array).duplicate(), "items": (s["items"] as Array).duplicate(),
		"dropped": s["dropped"], "role": s["role"], "team": s["team"],
		"spike": s["role"] == &"butler" and not s["spiked"] and s["alive"] and round_no >= 2,
		"target": pour_target(seat),
	}
	if not s["alive"] and rules.get("ghosts_see_cups", true):
		var view: Array = []
		for t in cup_at.size():
			var kinds: Array = []
			for c: Dictionary in cups[cup_at[t]]["contents"]:
				kinds.append(c["k"])
			view.append(kinds)
		out["ghost_view"] = view
	return out
