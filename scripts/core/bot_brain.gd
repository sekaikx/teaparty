class_name BotBrain
extends RefCounted
## A computer guest in "Murder at Teatime". It only uses what a player in its seat could know:
## its hand, role, evidence (what it glimpsed, sniffed, watched), the public reveal, and the
## claims other guests make at the meeting.
##   Innocent bots pour harmless cards, tell the truth, and vote for whoever the evidence points at.
##   Poisoner bots poison an innocent, invent an alibi, sometimes frame someone, and vote with
##   the crowd (never for a partner).

const I := Defs.Ingredient
const IT := Defs.Item

var seat := -1
var rng := RandomNumberGenerator.new()
## 0.2 .. 0.9: how bold (framing, accusing, swapping).
var aggression := 0.5
var poisoner := false
var partners: Array = []
## This round: my true evidence, claims heard {seat: [claims]}, poisoned seats (died or saved).
var evidence: Array = []
var heard: Dictionary = {}
var poisoned: Array[int] = []
var _claimed := 0


func _init(p_seat: int, seed_value: int) -> void:
	seat = p_seat
	rng.seed = seed_value
	aggression = rng.randf_range(0.3, 0.9)


func new_round(_pub: Dictionary) -> void:
	evidence = []
	heard.clear()
	poisoned.clear()
	_claimed = 0


func _others_alive(pub: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var ss: Array = pub.get("seats", [])
	for i in ss.size():
		if i != seat and ss[i]["alive"]:
			out.append(i)
	return out


func _sync(priv: Dictionary) -> void:
	poisoner = priv.get("role", &"guest") == &"poisoner"
	partners = priv.get("partners", [])
	if priv.has("evidence"):
		evidence = priv["evidence"]


func _pick(a: Array) -> int:
	return int(a[rng.randi_range(0, a.size() - 1)]) if not a.is_empty() else -1


# ---------------------------------------------------------------- serve

## {"index": card, "target": seat}
func choose_serve(priv: Dictionary, pub: Dictionary) -> Dictionary:
	_sync(priv)
	var hand: Array = priv.get("hand", [])
	var others := _others_alive(pub)
	if hand.is_empty() or others.is_empty():
		return {}
	if poisoner:
		var victims: Array[int] = []
		for o in others:
			if not partners.has(o):
				victims.append(o)
		var idx := hand.find(I.POISON)
		# A careful poisoner now and then pours something harmless to keep a clean record.
		if idx >= 0 and rng.randf() < 0.9 and not victims.is_empty():
			return {"index": idx, "target": _pick(victims)}
		return {"index": maxi(0, hand.find(I.SUGAR)), "target": _pick(others)}
	var anti := hand.find(I.ANTIDOTE)
	if anti >= 0:
		return {"index": anti, "target": _pick(others)}
	return {"index": rng.randi_range(0, hand.size() - 1), "target": _pick(others)}


# ---------------------------------------------------------------- items

## {} to pass, else {"index": item index, "targets": Array[int] seats}.
func choose_item(priv: Dictionary, pub: Dictionary) -> Dictionary:
	_sync(priv)
	var items: Array = priv.get("items", [])
	var others := _others_alive(pub)
	if items.is_empty() or others.is_empty():
		return {}
	var idx := items.find(IT.SNIFF)
	if idx >= 0 and not poisoner:
		# Sniff your own cup most of the time: knowing it's poisoned lets you spill it at the toast.
		return {"index": idx, "targets": [seat if rng.randf() < 0.7 else _pick(others)]}
	idx = items.find(IT.PEEK)
	if idx >= 0:
		var saw_who := -1
		for e: Dictionary in evidence:
			if e.get("kind", "") == "saw":
				saw_who = int(e["who"])
		var pool := others.duplicate()
		pool.erase(saw_who)
		if pool.is_empty():
			pool = others
		return {"index": idx, "targets": [_pick(pool)]}
	idx = items.find(IT.SWAP)
	if idx >= 0 and rng.randf() < 0.25 * aggression and others.size() >= 2:
		var a := _pick(others)
		var rest := others.duplicate()
		rest.erase(a)
		return {"index": idx, "targets": [a, _pick(rest)]}
	return {}


func on_private_event(ev: Dictionary, _pub: Dictionary) -> void:
	match String(ev.get("type", "")):
		"sniff_result":
			evidence.append({"kind": "sniff", "target": int(ev["target"]), "smell": String(ev["smell"])})
		"watch_result":
			evidence.append({"kind": "watch", "who": int(ev["who"]), "into": int(ev["into"])})


## Scared of its own cup (it sniffed poison, or just nervous)? Then it tries to cake it away.
func fears_own_cup(_pub: Dictionary) -> bool:
	for e: Dictionary in evidence:
		if e.get("kind", "") == "sniff" and int(e["target"]) == seat and String(e["smell"]) == "poison":
			return true
	return rng.randf() < 0.12


# ---------------------------------------------------------------- the meeting

func on_reveal(list: Array) -> void:
	for r: Dictionary in list:
		poisoned.append(int(r["seat"]))


func hear(claim: Dictionary) -> void:
	var by := int(claim.get("seat", -1))
	if by == seat:
		return
	var arr: Array = heard.get(by, [])
	arr.append(claim)
	heard[by] = arr


## The next thing this bot says at the meeting, or {} when it has nothing (more) to say.
func next_claim(priv: Dictionary, pub: Dictionary) -> Dictionary:
	_sync(priv)
	_claimed += 1
	var others := _others_alive(pub)
	if others.is_empty():
		return {}
	var my_pour: Dictionary = {}
	var my_saw: Dictionary = {}
	for e: Dictionary in evidence:
		match String(e.get("kind", "")):
			"poured":
				my_pour = e
			"saw", "watch":
				if my_saw.is_empty() or e["kind"] == "watch":
					my_saw = e
	if poisoner:
		match _claimed:
			1:
				# A fake alibi: "I poured sugar into <someone who didn't die>'s cup".
				var pool: Array[int] = []
				for o in others:
					if not poisoned.has(o):
						pool.append(o)
				var fake := _pick(pool if not pool.is_empty() else others)
				return {"kind": &"poured", "a": fake, "k": I.SUGAR if rng.randf() < 0.5 else I.NOTHING}
			2:
				if rng.randf() < aggression and not poisoned.is_empty():
					# Frame an innocent: "I saw X pour into the victim's cup!"
					var pool: Array[int] = []
					for o in others:
						if not partners.has(o):
							pool.append(o)
					if not pool.is_empty():
						return {"kind": &"saw", "a": _pick(pool), "b": poisoned[0]}
				return {}
			3:
				var target := _most_accused(pub)
				return {"kind": &"sus", "a": target} if target >= 0 else {}
		return {}
	match _claimed:
		1:
			if not my_pour.is_empty():
				return {"kind": &"poured", "a": int(my_pour["into"]), "k": int(my_pour["k"])}
		2:
			if not my_saw.is_empty() and int(my_saw.get("into", -1)) >= 0:
				return {"kind": &"saw" if my_saw["kind"] == "saw" else &"watch", "a": int(my_saw["who"]), "b": int(my_saw["into"])}
		3:
			for e: Dictionary in evidence:
				if e.get("kind", "") == "sniff":
					return {"kind": &"sniff", "a": int(e["target"]), "smell": String(e["smell"])}
		4:
			var t := choose_vote(pub)
			return {"kind": &"sus", "a": t} if t >= 0 else {}
	return {}


## How suspicious each living guest looks to this bot. Truth first, then what others said.
func _score(pub: Dictionary) -> Dictionary:
	var score := {}
	for o in _others_alive(pub):
		if not partners.has(o):
			score[o] = 0.0
	# My own sightings are true.
	for e: Dictionary in evidence:
		var k := String(e.get("kind", ""))
		if (k == "saw" or k == "watch") and score.has(int(e["who"])):
			var who := int(e["who"])
			if poisoned.has(int(e["into"])):
				score[who] += 3.0
			else:
				score[who] -= 1.0
			# Caught lying: they claimed they poured somewhere else.
			for c: Dictionary in heard.get(who, []):
				if c.get("kind", "") == &"poured" and int(c["a"]) != int(e["into"]):
					score[who] += 3.5
	# What others claim (could be lies, so worth less).
	for by: int in heard:
		for c: Dictionary in heard[by]:
			match StringName(c.get("kind", "")):
				&"saw", &"watch":
					var who := int(c["a"])
					if score.has(who) and poisoned.has(int(c["b"])):
						score[who] += 1.2
				&"poured":
					if score.has(by) and poisoned.has(int(c["a"])):
						score[by] += 0.8   # admitted pouring into the victim's cup
				&"sus":
					if score.has(int(c["a"])):
						score[int(c["a"])] += 0.4
	return score


func _most_accused(pub: Dictionary) -> int:
	var sc := _score(pub)
	var best := -1
	var best_v := -INF
	for o: int in sc:
		var v: float = sc[o] + rng.randf() * 0.3
		if v > best_v:
			best_v = v
			best = o
	return best


## Seconds between this bot's lines at the meeting.
func claim_delay(talk_time: float) -> float:
	return rng.randf_range(0.06, 0.16) * talk_time


## Seconds into the meeting before this bot is ready to vote.
func ready_delay(talk_time: float) -> float:
	return rng.randf_range(0.55, 0.85) * talk_time


## Who to throw out (-1 = skip).
func choose_vote(pub: Dictionary) -> int:
	var sc := _score(pub)
	if sc.is_empty():
		return -1
	if poisoner:
		# Go with the crowd against an innocent; never a partner.
		var t := _most_accused(pub)
		return t if rng.randf() < 0.85 else -1
	var best := -1
	var best_v := 1.4
	for o: int in sc:
		var v: float = sc[o] + rng.randf() * 0.2
		if v > best_v:
			best_v = v
			best = o
	return best


# ---------------------------------------------------------------- chatter, ghosts

func chatter_emote(_priv: Dictionary, _pub: Dictionary) -> int:
	if rng.randf() < aggression * 0.35:
		return 2   # accuse
	return [0, 1, 3, 4, 6, 7][rng.randi_range(0, 5)]


## Ghosts can't see inside cups: they just rattle one for spooky fun.
func choose_rattle(_priv: Dictionary, pub: Dictionary) -> int:
	var living: Array[int] = []
	var ss: Array = pub.get("seats", [])
	for i in ss.size():
		if ss[i]["alive"]:
			living.append(i)
	return _pick(living)
