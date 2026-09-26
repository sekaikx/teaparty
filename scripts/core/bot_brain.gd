class_name BotBrain
extends RefCounted
## A computer guest. It only uses what a player in its seat could know: its own tray and items,
## its sniff / peek results, and the public events (cups moving, toasts, deaths).
##
## Beliefs are kept per cup id (cups move when swapped): 0 = surely safe, 1 = surely deadly.

const I := Defs.Ingredient
const IT := Defs.Item

var seat := -1
var rng := RandomNumberGenerator.new()
## 0.2 (gentle) .. 0.9 (poisoner). Also how likely it is to lie with emotes.
var aggression := 0.5
var belief: Dictionary = {}


func _init(p_seat: int, seed_value: int) -> void:
	seat = p_seat
	rng.seed = seed_value
	aggression = rng.randf_range(0.3, 0.9)


func new_round(pub: Dictionary) -> void:
	belief.clear()
	var r: int = pub.get("round", 1)
	var prior := clampf(0.1 + 0.08 * (r - 1), 0.1, 0.6)
	if pub.get("laced", false):
		prior = 0.75
	for c: Dictionary in pub.get("cups", []):
		belief[int(c["id"])] = prior


func _cup_at(pub: Dictionary, s: int) -> int:
	var cups: Array = pub.get("cups", [])
	return int(cups[s]["id"]) if s >= 0 and s < cups.size() else -1


func _teammate(pub: Dictionary, other: int) -> bool:
	var ss: Array = pub.get("seats", [])
	if other < 0 or other >= ss.size():
		return false
	var mine: int = ss[seat]["team"]
	return mine >= 0 and mine == int(ss[other]["team"])


func _others_alive(pub: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var ss: Array = pub.get("seats", [])
	for i in ss.size():
		if i != seat and ss[i]["alive"]:
			out.append(i)
	return out


# ---------------------------------------------------------------- pour

func choose_pour(priv: Dictionary, pub: Dictionary) -> int:
	var hand: Array = priv.get("hand", [])
	if hand.is_empty():
		return -1
	var target: int = priv.get("target", -1)
	var friendly := _teammate(pub, target)
	var best := 0
	var best_w := -1.0
	for i in hand.size():
		var w := rng.randf() * 0.35
		match int(hand[i]):
			I.POISON:
				w += -1.0 if friendly else aggression
			I.ANTIDOTE:
				w += 0.9 if friendly else (1.0 - aggression) * 0.5
			I.SUGAR:
				w += 0.45
			I.NOTHING:
				w += 0.3
		if w > best_w:
			best_w = w
			best = i
	return best


func choose_spike(priv: Dictionary, pub: Dictionary) -> int:
	if not priv.get("spike", false):
		return -1
	var others := _others_alive(pub)
	return others[rng.randi_range(0, others.size() - 1)] if not others.is_empty() else -1


# ---------------------------------------------------------------- items

## {} to pass, else {"index": item index, "targets": Array[int] seats}.
func choose_item(priv: Dictionary, pub: Dictionary) -> Dictionary:
	var items: Array = priv.get("items", [])
	if items.is_empty():
		return {}
	var others := _others_alive(pub)
	if others.is_empty():
		return {}
	var mine := float(belief.get(_cup_at(pub, seat), 0.3))
	var idx := items.find(IT.SWAP)
	if idx >= 0 and mine >= 0.45:
		# Hand the cup to whoever holds the safest-looking cup that is not a teammate.
		var pick := -1
		var low := 2.0
		for o in others:
			var b := float(belief.get(_cup_at(pub, o), 0.3)) + rng.randf() * 0.15
			if _teammate(pub, o):
				b += 1.0
			if b < low:
				low = b
				pick = o
		if pick >= 0:
			return {"index": idx, "targets": [seat, pick]}
	idx = items.find(IT.SNIFF)
	if idx >= 0 and absf(mine - 0.5) < 0.45:
		return {"index": idx, "targets": [seat]}
	idx = items.find(IT.TOAST)
	if idx >= 0 and rng.randf() < aggression * 0.7:
		var victim := -1
		var high := -1.0
		for o in others:
			var b := float(belief.get(_cup_at(pub, o), 0.3)) + rng.randf() * 0.3
			if _teammate(pub, o):
				b -= 1.0
			if b > high:
				high = b
				victim = o
		if victim >= 0:
			return {"index": idx, "targets": [victim]}
	idx = items.find(IT.PEEK)
	if idx >= 0 and rng.randf() < 0.45:
		return {"index": idx, "targets": [others[rng.randi_range(0, others.size() - 1)]]}
	idx = items.find(IT.SWAP)
	if idx >= 0 and rng.randf() < 0.25:
		return {"index": idx, "targets": [seat, others[rng.randi_range(0, others.size() - 1)]]}
	return {}


func on_private_event(ev: Dictionary, pub: Dictionary) -> void:
	if ev.get("type", "") == "sniff_result":
		var cup := _cup_at(pub, int(ev["target"]))
		match String(ev["smell"]):
			"poison":
				belief[cup] = 0.85
			"clean":
				belief[cup] = 0.0

# ---------------------------------------------------------------- talk, ghosts

## Seconds into the talk before this bot says it is ready to drink.
func ready_delay(talk_time: float) -> float:
	return rng.randf_range(0.2, 0.55) * talk_time


func chatter_emote(priv: Dictionary, pub: Dictionary) -> int:
	var mine := float(belief.get(_cup_at(pub, seat), 0.3))
	if mine > 0.6:
		return 5 if rng.randf() < 0.5 else 1   # "Please, spare me!" / "It wasn't me!"
	var roll := rng.randf()
	if roll < aggression * 0.4:
		return 2   # accuse
	return [0, 1, 3, 4, 6, 7][rng.randi_range(0, 5)]


## Ghosts see every cup; most rattle a deadly one as a warning, some just stir trouble.
func choose_rattle(priv: Dictionary, pub: Dictionary) -> int:
	var view: Array = priv.get("ghost_view", [])
	var living: Array[int] = []
	var deadly: Array[int] = []
	var ss: Array = pub.get("seats", [])
	for i in ss.size():
		if ss[i]["alive"]:
			living.append(i)
			if i < view.size():
				var cs: Array = []
				for k: int in view[i]:
					cs.append({"k": k, "by": -1})
				if TeaRules.lethal(cs):
					deadly.append(i)
	if living.is_empty():
		return -1
	if not deadly.is_empty() and rng.randf() < 0.65:
		return deadly[rng.randi_range(0, deadly.size() - 1)]
	return living[rng.randi_range(0, living.size() - 1)]
