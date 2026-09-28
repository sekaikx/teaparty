class_name TeaRules
extends RefCounted
## The whole game as pure data: seats, roles, hands, cups, evidence, votes and win conditions.
## No nodes, no networking; Session (the host) drives it and tools/test_rules.gd exercises it.
##
## "Murder at Teatime", a hidden-killer social deduction game around a tea table:
##   SERVE (in the dark)  every guest secretly pours one card into ANY other guest's cup.
##                        The secret POISONER(s) hold poison. Innocents hold sugar, plain tea and,
##                        for one lucky guest, an antidote.
##   You glimpse one pour Each guest privately sees one other guest's pour ("Baron poured into
##                        Ada's cup"). That's the evidence everyone argues about.
##   ITEMS                SNIFF a cup (poison?), WATCH a guest (whose cup did they pour into?),
##                        SWAP two cups.
##   THE TOAST            Cups up. Cakes can knock a cup away. Everyone drinks; the poisoned fall.
##   THE MEETING          Talk: alibis ("I poured sugar into Clara's"), sightings, accusations.
##   THE VOTE             Most votes gets thrown out of the party (and their role is shown).
## Innocents win when every poisoner is out. Poisoners win when they're as many as the innocents.
##
## Seats are fixed places around the table (the dead stay seated as ghosts). Cups move:
## `cup_at[seat]` is the cup in front of a seat, so a swap exchanges two entries. Each cup holds a
## list of {k: Ingredient, by: seat}. A drinker falls when their cup holds more poison than antidote.

const I := Defs.Ingredient
const IT := Defs.Item
const POISONER := &"poisoner"
const GUEST := &"guest"
const INSPECTOR := &"inspector"
const PHYSICIAN := &"physician"

var rng := RandomNumberGenerator.new()
var rules: Dictionary = Defs.default_rules()
var seats: Array[Dictionary] = []
var cups: Dictionary = {}
var cup_at: Array[int] = []
var round_no := 0
## Kept for older callers; the pot is never laced in this mode.
var laced := false
## Drinks this round in order: {seat, cup, contents, died, ...}.
var drinks: Array[Dictionary] = []
## Seats that fell in the most recent drinking (or the vote).
var fallen_last: Array[int] = []
## seat -> target seat (or -1 = skip) for the current vote.
var votes: Dictionary = {}
## seat -> the Physician's seat, for guests watched over this round.
var protected: Dictionary = {}
## This round's twist (&"" for none) and the gossip it spread.
var twist: StringName = &""
var gossip: Dictionary = {}


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
			"alive": true, "team": -1, "role": GUEST,
			"hand": [], "items": [], "poured": false, "dropped": -1, "served": -1,
			"item_done": false, "ready": false, "voted": false, "rattles": 0, "died_round": -1,
			"ejected": false, "evidence": [],
			"kills": 0, "rounds_survived": 0, "sniffs": 0, "toasts": 0, "swaps": 0, "peeks": 0,
			"rattles_used": 0, "good_votes": 0,
			"inspects": 0, "revives": 0, "last_protect": -1, "self_protected": false,
		})
		cups[i] = {"id": i, "owner": i, "contents": [], "tea": false, "drunk": false}
		cup_at.append(i)
	# The secret poisoner(s).
	var order: Array = range(seats.size())
	_shuffle(order)
	var np := mini(poisoner_count(seats.size()), seats.size())
	for n in np:
		seats[order[n]]["role"] = POISONER
	# The special innocents, from the rest of the shuffled order.
	var next := np
	for r: StringName in [INSPECTOR, PHYSICIAN]:
		if bool(rules.get(String(r), true)) and seats.size() >= int(Defs.ROLES[r]["min_players"]) and next < seats.size():
			seats[order[next]]["role"] = r
			next += 1


## The role card a seat gets every round (-1 for none).
func role_card(seat: int) -> int:
	var r: StringName = seats[seat]["role"]
	return int(Defs.ROLES.get(r, {}).get("card", -1))


func has_role(r: StringName) -> bool:
	for s in seats:
		if s["role"] == r:
			return true
	return false


## Tuned in tools/test_rules.gd so the poisoner(s) win roughly 40-50% against bots: bigger
## tables give more time to catch one poisoner (fewer glimpses), but two poisoners need more.
static func glimpse_for(players: int) -> float:
	return {3: 0.7, 4: 0.6, 5: 0.5, 6: 0.4, 7: 0.33}.get(players, 0.75) as float


## The Inspector and the Physician are strong evidence and protection for the guests, so with
## them at the table the candles flicker more (fewer glimpses). Tuned in tools/test_rules.gd.
func role_glimpse_k() -> float:
	var k := 1.0
	if has_role(INSPECTOR):
		k *= IK
	if has_role(PHYSICIAN):
		k *= PK
	return k


static var IK := 0.6
static var PK := 0.85


static func poisoner_count(players: int) -> int:
	return 2 if players >= 8 else 1


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


func is_poisoner(seat: int) -> bool:
	return seat >= 0 and seat < seats.size() and seats[seat]["role"] == POISONER


func seat_of_id(id: int) -> int:
	for i in seats.size():
		if int(seats[i]["id"]) == id:
			return i
	return -1


func poisoner_seats() -> Array[int]:
	var out: Array[int] = []
	for i in seats.size():
		if is_poisoner(i):
			out.append(i)
	return out


# ---------------------------------------------------------------- rounds and dealing

func start_round() -> void:
	round_no += 1
	drinks.clear()
	fallen_last.clear()
	votes.clear()
	for i in seats.size():
		var s := seats[i]
		s["hand"] = []
		s["poured"] = false
		s["dropped"] = -1
		s["served"] = -1
		s["item_done"] = false
		s["ready"] = false
		s["voted"] = false
		s["evidence"] = []
		s["rattles"] = int(rules["ghost_rattles"]) if not s["alive"] else 0
	protected.clear()
	gossip = {}
	# Most rounds bring a twist (never the first, so a first game starts plain).
	twist = &""
	if bool(rules.get("twists", true)) and round_no >= 2 and rng.randf() < 0.65:
		var ids: Array = Defs.TWISTS.keys()
		twist = ids[rng.randi_range(0, ids.size() - 1)]
	for seat in seats.size():
		var cup: Dictionary = cups[cup_at[seat]]
		cup["contents"] = []
		cup["tea"] = false
		cup["drunk"] = not seats[seat]["alive"]
		cup["swapped_by"] = -1
		cup["spilled"] = false
		cup["spilled_by"] = -1
	# Hands: poisoners get poison plus two harmless cards (they may choose not to kill);
	# innocents get harmless cards, and one random innocent gets the antidote.
	var alive := alive_seats()
	var innocents: Array[int] = []
	# Poisoners share ONE vial a round (like a kill cooldown): it goes to one of the living ones.
	var living_p: Array[int] = []
	for seat in alive:
		if is_poisoner(seat):
			living_p.append(seat)
	var vial := living_p[rng.randi_range(0, living_p.size() - 1)] if not living_p.is_empty() else -1
	for seat in alive:
		if is_poisoner(seat):
			seats[seat]["hand"] = [I.POISON, I.SUGAR, I.NOTHING] if seat == vial else [I.SUGAR, I.NOTHING, I.NOTHING]
		else:
			innocents.append(seat)
			var hand: Array = []
			for n in 3:
				hand.append(I.SUGAR if rng.randf() < (0.8 if twist == &"sugar_rush" else 0.4) else I.NOTHING)
			seats[seat]["hand"] = hand
	# One antidote a round (two at a big table with two poisoners).
	_shuffle(innocents)
	for n in mini(2 if poisoner_count(seats.size()) >= 2 else 1, innocents.size()):
		(seats[innocents[n]]["hand"] as Array)[0] = I.ANTIDOTE
	for seat in alive:
		(seats[seat]["hand"] as Array).sort()
		seats[seat]["items"] = []
		for n in int(rules["items_per_round"]) + (1 if twist == &"favours" else 0):
			_give_item(seats[seat])
		var rc := role_card(seat)
		if rc >= 0:
			(seats[seat]["items"] as Array).push_front(rc)


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


# ---------------------------------------------------------------- serving (in the dark)

## Who `seat` poured into this round (-1 if they haven't yet).
func pour_target(seat: int) -> int:
	return int(seats[seat]["served"]) if seat >= 0 and seat < seats.size() else -1


func can_serve(seat: int, target: int) -> bool:
	return is_alive(seat) and is_alive(target) and target != seat and not seats[seat]["poured"]


## Pour the card at `card_index` of your hand into `target`'s cup (any living guest but you).
func pour(seat: int, card_index: int, target: int) -> bool:
	if not can_serve(seat, target):
		return false
	var hand: Array = seats[seat]["hand"]
	if card_index < 0 or card_index >= hand.size():
		return false
	var k: int = hand[card_index]
	hand.remove_at(card_index)
	var cup: Dictionary = cups[cup_at[target]]
	(cup["contents"] as Array).append({"k": k, "by": seat})
	seats[seat]["poured"] = true
	seats[seat]["dropped"] = k
	seats[seat]["served"] = target
	(seats[seat]["evidence"] as Array).append({"kind": "poured", "k": k, "into": target})
	return true


## Out of time: a harmless card into a random cup (the clock never poisons for you).
func auto_pour(seat: int) -> int:
	var hand: Array = seats[seat]["hand"]
	var others := alive_seats()
	others.erase(seat)
	if others.is_empty() or hand.is_empty():
		seats[seat]["poured"] = true
		return I.NOTHING
	var idx := 0
	for i in hand.size():
		if hand[i] != I.POISON:
			idx = i
			break
	var k: int = hand[idx]
	pour(seat, idx, others[rng.randi_range(0, others.size() - 1)])
	return k


func all_poured() -> bool:
	for seat in alive_seats():
		if not seats[seat]["poured"]:
			return false
	return true


## After the serve: most living guests glimpsed ONE other guest's pour (the candles flicker, so
## some saw nothing). Returns seat -> sighting. Sightings are true; what people SAY is up to them.
func deal_sightings() -> Dictionary:
	var out := {}
	var alive := alive_seats()
	var chance := float(rules.get("glimpse_chance", -1.0))
	if chance < 0.0:
		chance = glimpse_for(seats.size()) * role_glimpse_k()
	if twist == &"blackout":
		chance = 0.0
	elif twist == &"full_moon":
		chance = 1.0
	for seat in alive:
		if rng.randf() > chance:
			(seats[seat]["evidence"] as Array).append({"kind": "dark"})
			out[seat] = {"kind": "dark", "who": -1, "into": -1}
			continue
		var pool: Array[int] = []
		for o in alive:
			if o != seat and int(seats[o]["served"]) >= 0:
				pool.append(o)
		if pool.is_empty():
			continue
		var who: int = pool[rng.randi_range(0, pool.size() - 1)]
		var ev := {"kind": "saw", "who": who, "into": int(seats[who]["served"])}
		(seats[seat]["evidence"] as Array).append(ev)
		out[seat] = ev
	for seat in alive:
		cups[cup_at[seat]]["tea"] = true
	if twist == &"gossip":
		var pourers: Array[int] = []
		for o in alive:
			if int(seats[o]["served"]) >= 0:
				pourers.append(o)
		if not pourers.is_empty():
			var who: int = pourers[rng.randi_range(0, pourers.size() - 1)]
			gossip = {"who": who, "into": int(seats[who]["served"])}
			for o in alive:
				(seats[o]["evidence"] as Array).append({"kind": "gossip", "who": who, "into": gossip["into"]})
	return out


# ---------------------------------------------------------------- items (everyone at once)
# Everybody picks an item and its targets during the same short window; then they all play out
# in a fixed order: sniffs and watches first (information), then swaps (the cups move).

const ITEM_ORDER := [Defs.Item.PROTECT, Defs.Item.INSPECT, Defs.Item.SNIFF, Defs.Item.PEEK, Defs.Item.LEAVES,
	Defs.Item.SWAP, Defs.Item.FRESH, Defs.Item.TOAST]

## seat -> {"index": item index, "item": item, "targets": Array} or {} for a pass.
var picks: Dictionary = {}
## The same for role cards (the Inspector and the Physician play theirs on top of an item).
var role_picks: Dictionary = {}


func begin_items() -> void:
	picks.clear()
	role_picks.clear()
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
	if not picks.has(seat):
		picks[seat] = {}
	return true


## Done once the normal item and the role card (whichever the seat holds) are both picked.
func _turn_complete(seat: int) -> bool:
	var has_normal := false
	var has_role := false
	for k: int in seats[seat]["items"]:
		if Defs.is_role_card(k):
			has_role = true
		else:
			has_normal = true
	return (picks.has(seat) or not has_normal) and (role_picks.has(seat) or not has_role)


## Indices of the cards already locked in this items phase.
func picked_indices(seat: int) -> Array:
	var out: Array = []
	for d: Dictionary in [picks.get(seat, {}), role_picks.get(seat, {})]:
		if d.has("index"):
			out.append(int(d["index"]))
	return out


## Validates targets for an item (seat indices). Returns "" when fine, else the reason.
func item_error(seat: int, item: int, targets: Array) -> String:
	var need: int = Defs.ITEMS[item]["targets"]
	if targets.size() != need:
		return "Pick %d target%s." % [need, "s" if need > 1 else ""]
	for t: int in targets:
		if not is_alive(t):
			return "Only living guests."
	match item:
		IT.SWAP:
			if targets[0] == targets[1]:
				return "Pick two different cups."
		IT.TOAST, IT.PEEK, IT.INSPECT:
			if targets[0] == seat:
				return "Pick another guest."
		IT.PROTECT:
			if int(targets[0]) == int(seats[seat]["last_protect"]):
				return "Not the same guest two rounds running."
			if int(targets[0]) == seat and bool(seats[seat]["self_protected"]):
				return "You've already watched over yourself once."
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
	var role := Defs.is_role_card(item)
	if (role_picks if role else picks).has(seat):
		return "You've already picked that."
	var err := item_error(seat, item, targets)
	if err != "":
		return err
	(role_picks if role else picks)[seat] = {"index": item_index, "item": item, "targets": targets.duplicate()}
	seats[seat]["item_done"] = _turn_complete(seat)
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
	for kind: int in ITEM_ORDER:
		for seat in order:
			var pk: Dictionary = (role_picks if Defs.is_role_card(kind) else picks).get(seat, {})
			if pk.is_empty() or int(pk["item"]) != kind:
				continue
			# Role cards are played in secret: nothing public, so nobody learns who holds them.
			var step := {"seat": seat, "item": kind, "public": [], "private": [], "secret": Defs.is_role_card(kind)}
			steps.append(step)
			var targets: Array = pk["targets"]
			_remove_item(seat, kind)
			if not is_alive(seat) or item_error(seat, kind, targets) != "":
				step["public"].append({"type": "note", "text": "%s's %s fizzles." % [seats[seat]["name"], Defs.item_name(kind)]})
				continue
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
					var sm := smell(t)
					(seats[seat]["evidence"] as Array).append({"kind": "sniff", "target": t, "smell": sm})
					step["public"].append({"type": "sniff", "seat": seat, "target": t})
					step["private"].append({"type": "sniff_result", "target": t, "smell": sm})
				IT.PEEK:
					# WATCH: learn whose cup this guest poured into.
					var t: int = targets[0]
					seats[seat]["peeks"] += 1
					var into := int(seats[t]["served"])
					(seats[seat]["evidence"] as Array).append({"kind": "watch", "who": t, "into": into})
					step["public"].append({"type": "peek", "seat": seat, "target": t})
					step["private"].append({"type": "watch_result", "who": t, "into": into})
				IT.LEAVES:
					var t: int = targets[0]
					var n := (cups[cup_at[t]]["contents"] as Array).size()
					(seats[seat]["evidence"] as Array).append({"kind": "leaves", "target": t, "count": n})
					step["public"].append({"type": "leaves", "seat": seat, "target": t})
					step["private"].append({"type": "leaves_result", "target": t, "count": n})
				IT.FRESH:
					var t: int = targets[0]
					var cup: Dictionary = cups[cup_at[t]]
					var deadly := lethal(cup["contents"])
					cup["contents"] = []
					cup["fresh_by"] = seat
					step["public"].append({"type": "fresh", "seat": seat, "target": t})
					if deadly:
						step["public"].append({"type": "moments", "list": [{"title": "BUTLER SAVE!",
							"sub": "The butler took away %s's cup... and it was POISONED" % seats[t]["name"]}]})
				IT.INSPECT:
					var t: int = targets[0]
					seats[seat]["inspects"] += 1
					# Poison leaves a trace on the hands of whoever poured it THIS round: a poisoner
					# who lies low for a round comes up clean.
					var guilty := int(seats[t]["dropped"]) == I.POISON
					(seats[seat]["evidence"] as Array).append({"kind": "inspect", "who": t, "guilty": guilty})
					step["private"].append({"type": "inspect_result", "who": t, "guilty": guilty})
				IT.PROTECT:
					var t: int = targets[0]
					protected[t] = seat
					seats[seat]["last_protect"] = t
					if t == seat:
						seats[seat]["self_protected"] = true
					(seats[seat]["evidence"] as Array).append({"kind": "protect", "who": t})
					step["private"].append({"type": "protect_done", "who": t})
				IT.TOAST:
					var t: int = targets[0]
					seats[seat]["toasts"] += 1
					step["public"].append({"type": "toast", "seat": seat, "target": t})
					step["public"].append(drink(t, true))
	picks.clear()
	role_picks.clear()
	return steps


func _remove_item(seat: int, kind: int) -> void:
	var items: Array = seats[seat]["items"]
	var i := items.find(kind)
	if i >= 0:
		items.remove_at(i)


## Knocked over (a cake): the cup is emptied, so it's safe to drink. Returns true if it was deadly.
func spill(seat: int, by: int = -1) -> bool:
	if seat < 0 or seat >= cup_at.size() or not is_alive(seat):
		return false
	var cup: Dictionary = cups[cup_at[seat]]
	if cup["drunk"]:
		return false
	var was_lethal := lethal(cup["contents"])
	cup["contents"] = []
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


## Ghosts rattle a living guest's cup (spooky, a limited number of times per round).
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


static func has_poison(contents: Array) -> bool:
	for c: Dictionary in contents:
		if c["k"] == I.POISON:
			return true
	return false


func _drink_event(seat: int, contents: Array, died: bool, toast: bool) -> Dictionary:
	var cup: Dictionary = cups[cup_at[seat]]
	# The Physician's smelling salts: a guest they watched over survives a deadly cup.
	var revived := died and protected.has(seat)
	if revived:
		died = false
		var doc := int(protected[seat])
		seats[doc]["revives"] += 1
	return {"type": "drink", "seat": seat, "cup": cup_at[seat], "contents": contents, "died": died, "toast": toast,
		"saved": has_poison(contents) and not died, "revived": revived, "spilled": bool(cup.get("spilled", false)),
		"role": seats[seat]["role"], "blame": blame(contents, cup)}


## The seat drinks the cup in front of it. Returns the drink event (host side: "blame" names the
## poisoners; Session strips that before telling anyone).
func drink(seat: int, toast: bool = false) -> Dictionary:
	var cup: Dictionary = cups[cup_at[seat]]
	var contents: Array = (cup["contents"] as Array).duplicate(true) if not cup["drunk"] else []
	var died: bool = lethal(contents) and not bool(cup["drunk"])
	var ev := _drink_event(seat, contents, died, toast)
	cup["drunk"] = true
	drinks.append(ev)
	if ev["died"]:
		_kill(seat, contents)
	ev["moments"] = moments(ev)
	return ev


## Everyone still at the table drinks at once.
func drink_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var alive := alive_seats()
	fallen_last.clear()
	for seat in alive:
		var cup: Dictionary = cups[cup_at[seat]]
		var contents: Array = (cup["contents"] as Array).duplicate(true) if not cup["drunk"] else []
		out.append(_drink_event(seat, contents, lethal(contents), false))
		cup["drunk"] = true
	for ev in out:
		drinks.append(ev)
		if ev["died"]:
			_kill(ev["seat"], ev["contents"])
	for ev in out:
		ev["moments"] = moments(ev)
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


## Headline moments for a drink (the clip titles). Never names a living poisoner.
func moments(ev: Dictionary) -> Array:
	var out: Array = []
	var seat := int(ev["seat"])
	var nm: String = seats[seat]["name"]
	if ev.get("revived", false):
		out.append({"title": "SMELLING SALTS!", "sub": "%s drank POISON... and the Physician brought them round!" % nm})
		return out
	if ev.get("saved", false) and not ev.get("died", false):
		out.append({"title": "ANTIDOTE SAVE!", "sub": "%s's cup was POISONED... and someone slipped in the antidote" % nm})
		return out
	if not ev.get("died", false):
		return out
	var bl: Dictionary = ev.get("blame", {})
	if is_poisoner(seat):
		if (bl.get("poisoners", []) as Array).has(seat):
			out.append({"title": "OWN GOAL!", "sub": "The POISONER %s drank their own poison" % nm})
		else:
			out.append({"title": "POISONER DOWN!", "sub": "%s was a poisoner, and got poisoned" % nm})
	if int(bl.get("swapped_by", -1)) == seat:
		out.append({"title": "SELF-SWAP!", "sub": "%s swapped the deadly cup to THEMSELVES" % nm})
	return out


## Who's really to blame (host only, for kills and moments).
static func blame(contents: Array, cup: Dictionary) -> Dictionary:
	var by: Array = []
	for c: Dictionary in contents:
		if c["k"] == Defs.Ingredient.POISON and not by.has(int(c["by"])):
			by.append(int(c["by"]))
	return {"poisoners": by, "swapped_by": int(cup.get("swapped_by", -1)), "spilled": bool(cup.get("spilled", false)),
		"spilled_by": int(cup.get("spilled_by", -1))}


## The reveal: for each guest who fell (or was saved), what was in the cup, without names.
func reveal() -> Array:
	var out: Array = []
	for d in drinks:
		if not (d["died"] or d.get("saved", false)):
			continue
		var kinds: Array = []
		for c: Dictionary in d["contents"]:
			kinds.append(c["k"])
		kinds.sort()
		out.append({"seat": d["seat"], "kinds": kinds, "died": d["died"], "saved": d.get("saved", false),
			"revived": d.get("revived", false), "toast": d["toast"], "role": d["role"] if d["died"] else &""})
	return out


# ---------------------------------------------------------------- the vote

func begin_vote() -> void:
	votes.clear()
	for seat in seats.size():
		seats[seat]["voted"] = not seats[seat]["alive"]


## `target` -1 = skip. One vote each.
func vote(seat: int, target: int) -> bool:
	if not is_alive(seat) or seats[seat]["voted"]:
		return false
	if target != -1 and (not is_alive(target) or target == seat):
		return false
	votes[seat] = target
	seats[seat]["voted"] = true
	return true


func votes_done() -> bool:
	for seat in alive_seats():
		if not seats[seat]["voted"]:
			return false
	return true


## Count the votes and throw out the winner. Returns {ejected: seat or -1, role, tally: {target: n},
## votes: {voter: target}, reason}. A tie, or skips winning, throws nobody out.
func tally() -> Dictionary:
	var counts := {}
	for voter: int in votes:
		var t: int = votes[voter]
		counts[t] = int(counts.get(t, 0)) + 1
	var best := -1
	var best_n := 0
	var tie := false
	for t: int in counts:
		var n: int = counts[t]
		if n > best_n:
			best_n = n
			best = t
			tie = false
		elif n == best_n:
			tie = true
	var res := {"ejected": -1, "role": &"", "tally": counts, "votes": votes.duplicate(), "reason": ""}
	fallen_last.clear()
	if best_n == 0:
		res["reason"] = "Nobody voted."
	elif tie:
		res["reason"] = "A tie. Nobody is thrown out."
	elif best == -1:
		res["reason"] = "Most guests skipped. Nobody is thrown out."
	else:
		res["ejected"] = best
		res["role"] = seats[best]["role"]
		seats[best]["alive"] = false
		seats[best]["ejected"] = true
		seats[best]["died_round"] = round_no
		fallen_last.append(best)
		for voter: int in votes:
			if int(votes[voter]) == best and is_poisoner(best) and not is_poisoner(voter):
				seats[voter]["good_votes"] += 1
	return res


# ---------------------------------------------------------------- winning

## {over, winners: Array[int] seats, reason}
func check_winner(final_round_reached: bool = false) -> Dictionary:
	var p := 0
	var g := 0
	for s in alive_seats():
		if is_poisoner(s):
			p += 1
		else:
			g += 1
	var res := {"over": false, "winners": [], "reason": ""}
	var names: Array[String] = []
	for s in poisoner_seats():
		names.append(String(seats[s]["name"]))
	var who := " & ".join(names)
	if p == 0:
		res["over"] = true
		for i in seats.size():
			if not is_poisoner(i):
				res["winners"].append(i)
		res["reason"] = "Every poisoner is out. The guests win! (It was %s.)" % who
	elif p >= g or final_round_reached:
		res["over"] = true
		res["winners"] = poisoner_seats()
		res["reason"] = "%s poisoned the party and got away with it." % who
	return res


# ---------------------------------------------------------------- views

## What everyone may see.
func public_state() -> Dictionary:
	var ps: Array = []
	for i in seats.size():
		var s := seats[i]
		ps.append({
			"id": s["id"], "name": s["name"], "bot": s["bot"], "cos": s["cos"], "level": s["level"],
			"alive": s["alive"], "team": -1, "poured": s["poured"], "item_done": s["item_done"],
			"ready": s["ready"], "voted": s["voted"], "rattles": s["rattles"], "hand_count": (s["hand"] as Array).size(),
			"item_count": (s["items"] as Array).size(), "pour_target": -1, "ejected": s["ejected"],
			# Roles are shown once you're out (dead or thrown out).
			"role": s["role"] if not s["alive"] else &"",
		})
	var cs: Array = []
	for seat in cup_at.size():
		var c: Dictionary = cups[cup_at[seat]]
		# No content count: how many pours went into a cup is secret too.
		cs.append({"id": c["id"], "owner": c["owner"], "tea": c["tea"], "drunk": c["drunk"],
			"spilled": bool(c.get("spilled", false))})
	return {"round": round_no, "laced": false, "seats": ps, "cups": cs, "poisoners": poisoner_count(seats.size()),
		"roles_in_play": {"inspector": has_role(INSPECTOR), "physician": has_role(PHYSICIAN)},
		"twist": twist, "gossip": gossip}


## What one seat may see on top of the public state.
func private_state(seat: int) -> Dictionary:
	if seat < 0 or seat >= seats.size():
		return {}
	var s := seats[seat]
	var partners: Array = []
	if is_poisoner(seat):
		for o in poisoner_seats():
			if o != seat:
				partners.append(o)
	return {
		"seat": seat, "hand": (s["hand"] as Array).duplicate(), "items": (s["items"] as Array).duplicate(),
		"dropped": s["dropped"], "role": s["role"], "team": -1, "partners": partners,
		"target": int(s["served"]), "evidence": (s["evidence"] as Array).duplicate(true),
		"spike": false, "picked": picked_indices(seat),
		"last_protect": int(s["last_protect"]), "self_protected": bool(s["self_protected"]),
	}
