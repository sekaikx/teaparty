extends Node
## One match. The host runs TeaRules and the bots, and tells everyone what they may see:
##   public state  (everyone)   seats, cup positions, whose turn, the phase clock
##   private state (one seat)   your tray, items, role, what you dropped; ghosts see every cup
##   events        (animation)  pours, swaps, sniffs, toasts, drinks, rattles, emotes, the reveal
## Players send requests (pour, item, pass, ready, rattle, emote); the host checks them.
## Every peer has this autoload at the same path, so the RPCs line up.

signal match_began
signal state_changed
signal game_event(ev: Dictionary)
signal match_over(result: Dictionary)

const P := Defs.Phase
const INTRO_TIME := 4.5
const DEAL_TIME := 1.5
## The toast: cups raised for this long before everyone drinks (cakes can still knock them away).
const DRINK_TIME := 5.0
const REVEAL_TIME := 4.0
const REVEAL_PER_DEATH := 2.0
## Someone thrown out: the yeet, the role reveal.
const EJECT_TIME := 5.5
## Seconds between each locked-in item playing out.
const ITEM_STEP := 1.3
const END_DELAY := 1.0

var running := false
var roster: Array = []
var match_rules: Dictionary = {}
var public: Dictionary = {}
var private: Dictionary = {}
var phase: int = P.LOBBY
var phase_left := 0.0
var phase_total := 0.0
var my_seat := -1
var result: Dictionary = {}
## Timers run this much faster (tests / the QA harness).
var speed := 1.0

# host only
var _rules: TeaRules
var _bots: Dictionary = {}
var _bot_wait: Dictionary = {}
var _bot_chatter: Dictionary = {}
var _timer := 0.0
var _pending_end: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _steps: Array = []
var _step_timer := 0.0
var _resolving := false
## Per-seat fun stats for the end-of-match awards.
var _fun: Dictionary = {}
## This round's public item / ghost events, turned into talking points when the talk starts.
var _round_log: Array = []
## The host's 3D table, for cake hit tests (TableView sets itself here).
var world_probe: Object


func _ready() -> void:
	_rng.randomize()


func hosting() -> bool:
	return running and _rules != null


func _local_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1


# ---------------------------------------------------------------- views (all peers)

func seat_info(seat: int) -> Dictionary:
	var ss: Array = public.get("seats", [])
	return ss[seat] if seat >= 0 and seat < ss.size() else {}


func seat_count() -> int:
	return (public.get("seats", []) as Array).size()


func am_alive() -> bool:
	return bool(seat_info(my_seat).get("alive", false))


## Can I lock in an item right now? (Everyone picks at the same time.)
func is_my_turn() -> bool:
	return phase == P.ITEMS and not bool(public.get("resolving", false)) and am_alive() \
		and not bool(seat_info(my_seat).get("item_done", true))


func items_resolving() -> bool:
	return phase == P.ITEMS and bool(public.get("resolving", false))


## Host side: the seat of a peer id (-1 if none), and whether that seat is alive.
func seat_of_peer(id: int) -> int:
	if _rules:
		return _rules.seat_of_id(id)
	for i in seat_count():
		if int(seat_info(i).get("id", -1)) == id:
			return i
	return -1


func seat_alive_host(seat: int) -> bool:
	return _rules.is_alive(seat) if _rules else bool(seat_info(seat).get("alive", true))


func seat_name(seat: int) -> String:
	return String(seat_info(seat).get("name", "?"))


func cup_of(seat: int) -> Dictionary:
	var cs: Array = public.get("cups", [])
	return cs[seat] if seat >= 0 and seat < cs.size() else {}


# ---------------------------------------------------------------- start / stop

func host_start(players: Array, p_rules: Dictionary) -> void:
	_rules = TeaRules.new()
	_rules.setup(players, p_rules, _rng.randi())
	_bots.clear()
	_bot_wait.clear()
	_bot_chatter.clear()
	_pending_end = {}
	_fun.clear()
	_resolving = false
	for s in _rules.seat_count():
		if _rules.seats[s]["bot"]:
			_bots[s] = BotBrain.new(s, _rng.randi())
	_begin.rpc(players, p_rules)
	_set_phase(P.INTRO, INTRO_TIME)


@rpc("authority", "call_local", "reliable")
func _begin(players: Array, p_rules: Dictionary) -> void:
	roster = players
	match_rules = p_rules
	result = {}
	running = true
	my_seat = -1
	for i in players.size():
		if int(players[i]["id"]) == _local_id():
			my_seat = i
	public = {}
	private = {}
	phase = P.INTRO
	match_began.emit()


## Local stop (leaving, or the host went away).
func abort() -> void:
	running = false
	_rules = null
	_bots.clear()
	phase = P.LOBBY
	public = {}
	private = {}


func on_peer_left(id: int) -> void:
	if not hosting():
		return
	var s := _rules.seat_of_id(id)
	if s < 0:
		return
	_rules.seats[s]["bot"] = true
	_rules.seats[s]["name"] = "%s (bot)" % _rules.seats[s]["name"]
	_bots[s] = BotBrain.new(s, _rng.randi())
	_bots[s].new_round(_rules.public_state())
	_bot_wait[s] = 1.0
	_emit({"type": "note", "text": "%s left the party; a bot takes the seat." % _rules.seats[s]["name"]})
	_push()


# ---------------------------------------------------------------- host loop

func _process(delta: float) -> void:
	if not running:
		return
	phase_left = maxf(0.0, phase_left - delta * speed)
	if not hosting():
		return
	var dt := delta * speed
	_timer -= dt
	_tick_bots(dt)
	match phase:
		P.INTRO:
			if _timer <= 0.0:
				_start_round()
		P.DEAL:
			if _timer <= 0.0:
				_set_phase(P.POUR, float(_rules.rules["pour_time"]))
				_schedule_bots_pour()
		P.POUR:
			if _rules.all_poured():
				_after_serve()
			elif _timer <= 0.0:
				for s in _rules.alive_seats():
					if not _rules.seats[s]["poured"]:
						var k := _rules.auto_pour(s)
						_emit({"type": "pour", "seat": s})
						_emit_private(s, {"type": "auto_pour", "k": k, "target": _rules.pour_target(s)})
				_after_serve()
		P.ITEMS:
			if _resolving:
				_step_timer -= dt
				if _step_timer <= 0.0:
					_play_next_step()
			elif _rules.items_done():
				_resolve_items()
			elif _timer <= 0.0:
				for s in _rules.alive_seats():
					if not _rules.seats[s]["item_done"]:
						_rules.pass_turn(s)
						_emit({"type": "pass", "seat": s, "timeout": true})
				_resolve_items()
		P.TALK:
			var all_ready := true
			for s in _rules.alive_seats():
				if not _rules.seats[s]["ready"]:
					all_ready = false
			if all_ready or _timer <= 0.0:
				_begin_vote()
		P.DRINK:
			if _timer <= 0.0:
				var drinks := _rules.drink_all()
				var deaths := 0
				for d in drinks:
					if d["died"]:
						deaths += 1
				_emit({"type": "drink_all", "drinks": _public_drinks(drinks)})
				_emit({"type": "moments", "list": _table_moments(drinks)})
				var rv := _rules.reveal()
				_emit({"type": "reveal", "cups": rv})
				for b: int in _bots:
					(_bots[b] as BotBrain).on_reveal(rv)
				_last_reveal = rv
				_set_phase(P.REVEAL, REVEAL_TIME + REVEAL_PER_DEATH * deaths)
		P.REVEAL:
			if _timer <= 0.0:
				var w := _pending_end
				if w.is_empty():
					w = _rules.check_winner()
				if w["over"]:
					_end_match(w)
				else:
					_begin_talk()
		P.VOTE:
			if _rules.votes_done() or _timer <= 0.0:
				var res := _rules.tally()
				res["type"] = "vote_result"
				_emit(res)
				if int(res["ejected"]) >= 0:
					var ej := int(res["ejected"])
					var caught: bool = res["role"] == TeaRules.POISONER
					_emit({"type": "moments", "list": [{"title": "CAUGHT THE POISONER!" if caught else "WRONG GUEST!",
						"sub": "%s %s" % [_nm(ej), "WAS a poisoner" if caught else "was innocent... the poisoner is still here"]}]})
				_set_phase(P.EJECT, EJECT_TIME if int(res["ejected"]) >= 0 else 3.0)
		P.EJECT:
			if _timer <= 0.0:
				var w := _rules.check_winner(_rules.round_no >= int(_rules.rules["max_rounds"]))
				if w["over"]:
					_end_match(w)
				else:
					_start_round()


## The clip titles for a whole toast. They never name a poisoner who's still at the table.
func _table_moments(drinks: Array) -> Array:
	var out: Array = []
	var deaths := 0
	for d: Dictionary in drinks:
		out.append_array(d.get("moments", []))
		if d["died"]:
			deaths += 1
	if deaths == 2:
		out.push_front({"title": "DOUBLE KILL!", "sub": "Two guests poisoned in one toast"})
	elif deaths >= 3:
		out.push_front({"title": "BLOODBATH!", "sub": "%d guests down in one toast" % deaths})
	return out


## What everyone is told about a drink: who drank and who fell, never who poured what.
func _public_drinks(drinks: Array) -> Array:
	var out: Array = []
	for d: Dictionary in drinks:
		out.append({"type": "drink", "seat": d["seat"], "cup": d["cup"], "died": d["died"], "toast": d["toast"],
			"saved": d.get("saved", false), "spilled": d.get("spilled", false), "role": d["role"] if d["died"] else &""})
	return out


func _set_phase(p: int, seconds: float) -> void:
	phase = p
	_timer = seconds
	_push(seconds)


func _start_round() -> void:
	_rules.start_round()
	_cakes.clear()
	_pending_end = {}
	_round_log.clear()
	_last_words.clear()
	var pub := _rules.public_state()
	for s: int in _bots:
		(_bots[s] as BotBrain).new_round(pub)
	_last_reveal = []
	_emit({"type": "round", "round": _rules.round_no, "laced": false})
	_set_phase(P.DEAL, DEAL_TIME)


## The serve is over: everyone glimpsed one pour. Then the items.
func _after_serve() -> void:
	var sightings := _rules.deal_sightings()
	for seat: int in sightings:
		var sg: Dictionary = sightings[seat]
		_emit_private(seat, {"type": "sighting", "who": sg["who"], "into": sg["into"]})
	_emit({"type": "lights_on"})
	_begin_items()


func _begin_items() -> void:
	_rules.begin_items()
	_resolving = false
	if _rules.items_done():
		_resolve_items()
		return
	_set_phase(P.ITEMS, float(_rules.rules["item_turn_time"]))
	_schedule_bot_items()


## Everyone has picked (or the clock ran out): play the items out one by one.
func _resolve_items() -> void:
	_steps = _rules.resolve_items()
	if _steps.is_empty():
		_after_items()
		return
	phase = P.ITEMS
	_resolving = true
	_step_timer = 0.3
	_timer = ITEM_STEP * _steps.size() + 0.5
	_push(_timer)


func _play_next_step() -> void:
	if _steps.is_empty():
		_resolving = false
		_after_items()
		return
	var step: Dictionary = _steps.pop_front()
	_emit({"type": "item_step", "seat": step["seat"], "item": step["item"]})
	for raw: Dictionary in step["public"]:
		var ev: Dictionary = _public_drinks([raw])[0] if raw.get("type", "") == "drink" else raw
		_emit(ev)
		_round_log.append(ev)
		if raw.get("type", "") == "drink" and not (raw.get("moments", []) as Array).is_empty():
			_emit({"type": "moments", "list": raw["moments"]})
	for ev: Dictionary in step["private"]:
		_emit_private(int(step["seat"]), ev)
	_step_timer = ITEM_STEP + (2.2 if int(step["item"]) == Defs.Item.TOAST else 0.0)
	_push(_timer)


## Conversation starters for the meeting, built only from what everyone saw. On a Discord
## call this is the "so... where did YOU pour?" moment.
func _talking_points() -> Array:
	var lines: Array = []
	var dead: Array[String] = []
	var saved: Array[String] = []
	for r: Dictionary in _last_reveal:
		if r["died"]:
			dead.append(_nm(r["seat"]))
		elif r.get("saved", false):
			saved.append(_nm(r["seat"]))
	if not dead.is_empty():
		lines.append("%s was poisoned. Everyone: say whose cup YOU poured into." % " and ".join(dead))
		lines.append("Who saw someone pour into %s's cup? Say it. (Or lie.)" % dead[0])
	elif not saved.is_empty():
		lines.append("%s's cup was poisoned but someone slipped in the antidote. Who poured there?" % saved[0])
	else:
		lines.append("Nobody died... but someone had poison. Where did everyone pour?")
	for ev: Dictionary in _round_log:
		match String(ev.get("type", "")):
			"sniff":
				var whose := "their own cup" if int(ev["seat"]) == int(ev["target"]) else "%s's cup" % _nm(ev["target"])
				lines.append("%s SNIFFED %s. What did they smell?" % [_nm(ev["seat"]), whose])
			"peek":
				lines.append("%s WATCHED %s. They know where %s poured. Ask them." % [_nm(ev["seat"]), _nm(ev["target"]), _nm(ev["target"])])
			"swap":
				lines.append("%s SWAPPED %s's and %s's cups. Why?" % [_nm(ev["seat"]), _nm(ev["a"]), _nm(ev["b"])])
	lines.append("Two guests claim the same cup? One of them is lying.")
	return lines.slice(0, 3)


func _nm(i: Variant) -> String:
	var n := int(i)
	return String(_rules.seats[n]["name"]) if n >= 0 and n < _rules.seats.size() else "?"


func _after_items() -> void:
	var w := _rules.check_winner()
	if w["over"]:
		_pending_end = w
		_set_phase(P.REVEAL, REVEAL_TIME + 1.5)
		return
	# The toast: everyone raises their cup; cakes can knock them away; then everyone drinks.
	_set_phase(P.DRINK, DRINK_TIME)
	_emit({"type": "countdown"})
	_schedule_bots_drink()


func _next_turn() -> void:
	_push(_timer)


## The meeting: everyone argues about who did it, then votes.
func _begin_talk() -> void:
	for s in _rules.seats.size():
		_rules.seats[s]["ready"] = false
	_set_phase(P.TALK, float(_rules.rules["talk_time"]))
	_emit({"type": "talking_points", "lines": _talking_points()})
	# Bots poisoned at this toast say their last words first.
	for s: int in _bots:
		if not _rules.is_alive(s) and not _rules.seats[s]["ejected"] and int(_rules.seats[s]["died_round"]) == _rules.round_no:
			var lw := (_bots[s] as BotBrain).last_words(_rules.private_state(s), _rules.public_state())
			if not lw.is_empty():
				_do_claim(s, lw)
	var talk := float(_rules.rules["talk_time"])
	for s: int in _bots:
		var b: BotBrain = _bots[s]
		if _rules.is_alive(s):
			_bot_wait[s] = b.ready_delay(talk)
			_bot_chatter[s] = _rng.randf_range(1.5, 4.0) + s * 0.6
		else:
			_bot_wait[s] = _rng.randf_range(3.0, talk * 0.6)


func _begin_vote() -> void:
	_rules.begin_vote()
	_set_phase(P.VOTE, float(_rules.rules.get("vote_time", 20.0)))
	_emit({"type": "vote_start"})
	for s: int in _bots:
		if _rules.is_alive(s):
			_bot_wait[s] = _rng.randf_range(2.0, 8.0)


func _fun_add(seat: int, key: String, n: int = 1) -> void:
	if seat < 0:
		return
	var d: Dictionary = _fun.get(seat, {})
	d[key] = int(d.get(key, 0)) + n
	_fun[seat] = d


## The funny awards on the results screen: one line each, for bragging and blaming.
func _awards() -> Array:
	var out: Array = []
	var best := func(key: String) -> int:
		var top := -1
		var val := 0
		for seat: int in _fun:
			var v := int((_fun[seat] as Dictionary).get(key, 0))
			if v > val:
				val = v
				top = seat
		return top
	var kills_top := -1
	var kills := 0
	var first := -1
	var first_round := 999
	for i in _rules.seats.size():
		var sv := _rules.seats[i]
		if int(sv["kills"]) > kills:
			kills = int(sv["kills"])
			kills_top = i
		var dr := int(sv["died_round"])
		if dr > 0 and dr < first_round:
			first_round = dr
			first = i
	if kills_top >= 0:
		out.append({"seat": kills_top, "title": "MASTER POISONER", "desc": ("%d guest poisoned" if kills == 1 else "%d guests poisoned") % kills})
	var det := -1
	var det_n := 0
	for i in _rules.seats.size():
		if int(_rules.seats[i]["good_votes"]) > det_n:
			det_n = int(_rules.seats[i]["good_votes"])
			det = i
	if det >= 0:
		out.append({"seat": det, "title": "DETECTIVE", "desc": "voted out %d poisoner(s)" % det_n})
	for spec: Array in [["hits", "SHARPSHOOTER", "%d cake(s) to the face"], ["saves", "GUARDIAN ANGEL", "knocked away %d deadly cup(s)"],
			["spills", "BUTTERFINGERS", "spilled %d cup(s)"], ["faces", "CAKE MAGNET", "took %d cake(s) to the face"]]:
		var top: int = best.call(spec[0])
		if top >= 0:
			out.append({"seat": top, "title": spec[1], "desc": spec[2] % int((_fun[top] as Dictionary)[spec[0]])})
	if first >= 0:
		out.append({"seat": first, "title": "FIRST TO FALL", "desc": "down in round %d" % first_round})
	return out


func _end_match(w: Dictionary) -> void:
	var seats_out: Array = []
	for s in _rules.seats:
		seats_out.append({"name": s["name"], "id": s["id"], "bot": s["bot"], "alive": s["alive"],
			"role": s["role"], "team": s["team"], "kills": s["kills"], "rounds_survived": s["rounds_survived"],
			"sniffs": s["sniffs"], "toasts": s["toasts"], "swaps": s["swaps"], "peeks": s["peeks"],
			"rattles_used": s["rattles_used"], "died_round": s["died_round"], "cos": s["cos"], "ejected": s["ejected"],
			"fun": _fun.get(seats_out.size(), {})})
	var res := {"winners": w["winners"], "reason": w["reason"], "seats": seats_out, "rounds": _rules.round_no,
		"mode": _rules.mode(), "awards": _awards()}
	_set_phase(P.MATCH_END, 0.0)
	_finish.rpc(res)
	_rules = null


@rpc("authority", "call_local", "reliable")
func _finish(res: Dictionary) -> void:
	result = res
	phase = P.MATCH_END
	running = false
	var me: Dictionary = {}
	if my_seat >= 0 and my_seat < (res["seats"] as Array).size():
		me = res["seats"][my_seat]
	var won := (res["winners"] as Array).has(my_seat)
	var mine := 0
	for a: Dictionary in res.get("awards", []):
		if int(a["seat"]) == my_seat:
			mine += 1
	var fun: Dictionary = me.get("fun", {})
	res["award"] = Profile.award(me, won, me.get("role", &"guest") == TeaRules.POISONER, mine, fun) if not me.is_empty() else {}
	match_over.emit(res)


# ---------------------------------------------------------------- sending

func _push(total: float = -1.0) -> void:
	var pub := _rules.public_state()
	pub["phase"] = phase
	var cakes := {}
	for k: int in _cakes:
		cakes[str(k)] = _cakes[k]
	pub["cakes"] = cakes
	pub["resolving"] = _resolving
	pub["last_words_used"] = _last_words.keys()
	for i in _rules.seats.size():
		pub["died_round_%d" % i] = int(_rules.seats[i]["died_round"])
	pub["left"] = maxf(_timer, 0.0)
	pub["total"] = total if total >= 0.0 else float(public.get("total", _timer))
	_recv_public.rpc(pub)
	for s in _rules.seat_count():
		if _rules.seats[s]["bot"]:
			continue
		var peer := int(_rules.seats[s]["id"])
		var priv := _rules.private_state(s)
		if peer == _local_id():
			_recv_private(priv)
		elif multiplayer.get_peers().has(peer):
			_recv_private.rpc_id(peer, priv)


@rpc("authority", "call_local", "reliable")
func _recv_public(pub: Dictionary) -> void:
	public = pub
	phase = int(pub.get("phase", phase))
	phase_left = float(pub.get("left", 0.0))
	phase_total = float(pub.get("total", phase_left))
	state_changed.emit()


@rpc("authority", "reliable")
func _recv_private(priv: Dictionary) -> void:
	private = priv
	state_changed.emit()


func _emit(ev: Dictionary) -> void:
	_recv_event.rpc(ev)


func _emit_private(seat: int, ev: Dictionary) -> void:
	if _rules.seats[seat]["bot"]:
		if _bots.has(seat):
			(_bots[seat] as BotBrain).on_private_event(ev, _rules.public_state())
		return
	var peer := int(_rules.seats[seat]["id"])
	if peer == _local_id():
		_recv_private_event(ev)
	elif multiplayer.get_peers().has(peer):
		_recv_private_event.rpc_id(peer, ev)


@rpc("authority", "call_local", "reliable")
func _recv_event(ev: Dictionary) -> void:
	game_event.emit(ev)


@rpc("authority", "reliable")
func _recv_private_event(ev: Dictionary) -> void:
	ev["private"] = true
	game_event.emit(ev)


# ---------------------------------------------------------------- requests (any peer -> host)

func _call_host(method: StringName, args: Array) -> void:
	if Net.is_host():
		callv(method, args)
	else:
		callv(&"rpc_id", [1, method] + args)


func request_pour(card_index: int, target: int = -1) -> void:
	_call_host(&"_rq_pour", [card_index, target])


## Say something at the meeting: {kind, a, b, k, smell} (see Defs.CLAIMS). It can be a lie.
func request_claim(claim: Dictionary) -> void:
	_call_host(&"_rq_claim", [claim])


## Vote to throw a guest out (-1 = skip).
func request_vote(target: int) -> void:
	_call_host(&"_rq_vote", [target])


func request_item(item_index: int, targets: Array) -> void:
	_call_host(&"_rq_item", [item_index, targets])


func request_pass() -> void:
	_call_host(&"_rq_pass", [])


func request_ready_up() -> void:
	_call_host(&"_rq_ready", [])


func request_rattle(target: int) -> void:
	_call_host(&"_rq_rattle", [target])


func request_emote(emote: int) -> void:
	_call_host(&"_rq_emote", [emote])


## Lob a cupcake at a point: hit a CUP and it's knocked over (emptied, so it's safe to drink);
## hit a HEAD and they're knocked off their chair (and drop a raised cup during the toast).
func request_throw(target: Vector3) -> void:
	_call_host(&"_rq_throw", [target])


func cakes_left() -> int:
	return int(public.get("cakes", {}).get(str(my_seat), CAKES_LIVING if am_alive() else CAKES_GHOST))


func _sender_seat() -> int:
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = _local_id()
	return _rules.seat_of_id(id) if _rules else -1


@rpc("any_peer", "reliable")
func _rq_pour(card_index: int, target: int) -> void:
	if hosting() and phase == P.POUR:
		_do_pour(_sender_seat(), card_index, target)


@rpc("any_peer", "reliable")
func _rq_claim(claim: Dictionary) -> void:
	if hosting() and phase in [P.TALK, P.VOTE]:
		_do_claim(_sender_seat(), claim)


@rpc("any_peer", "reliable")
func _rq_vote(target: int) -> void:
	if hosting() and phase == P.VOTE:
		_do_vote(_sender_seat(), target)


@rpc("any_peer", "reliable")
func _rq_item(item_index: int, targets: Array) -> void:
	if hosting() and phase == P.ITEMS:
		_do_item(_sender_seat(), item_index, targets)


@rpc("any_peer", "reliable")
func _rq_pass() -> void:
	if hosting() and phase == P.ITEMS and not _resolving:
		var s := _sender_seat()
		if _rules.pass_turn(s):
			_emit({"type": "pass", "seat": s})
			_push(_timer)


@rpc("any_peer", "reliable")
func _rq_ready() -> void:
	if hosting() and phase == P.TALK:
		_do_ready(_sender_seat())


@rpc("any_peer", "reliable")
func _rq_rattle(target: int) -> void:
	if hosting() and phase in [P.ITEMS, P.TALK, P.POUR, P.DRINK]:
		_do_rattle(_sender_seat(), target)


var _claim_ready: Dictionary = {}
## Seats that already said their last words this round.
var _last_words: Dictionary = {}
var _last_reveal: Array = []
const CAKES_LIVING := 3
const CAKES_GHOST := 2
const CAKE_COOLDOWN := 1.0
var _cakes: Dictionary = {}
var _cake_ready: Dictionary = {}


@rpc("any_peer", "reliable")
func _rq_throw(target: Vector3) -> void:
	if hosting():
		_throw(_sender_seat(), target)


## The host decides what a cake hits (from its own table), applies it to the rules, and tells
## everyone so they all see the same thing.
func _throw(s: int, target: Vector3) -> void:
	if s < 0 or phase in [P.INTRO, P.MATCH_END, P.REVEAL, P.DEAL]:
		return
	var ghost := not _rules.is_alive(s)
	var cap := CAKES_GHOST if ghost else CAKES_LIVING
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_cake_ready.get(s, 0.0)) or int(_cakes.get(s, cap)) <= 0:
		return
	_cake_ready[s] = now + CAKE_COOLDOWN / speed
	_cakes[s] = int(_cakes.get(s, cap)) - 1
	target = target.clamp(Vector3(-12, -1, -12), Vector3(12, 6, 12))
	var hit := {"kind": "miss", "seat": -1}
	if world_probe and is_instance_valid(world_probe):
		hit = world_probe.call(&"hit_test", target, s)
	var kind := String(hit["kind"])
	var victim := int(hit["seat"])
	_fun_add(s, "thrown")
	var saved := false
	var spilled := false
	if kind == "cup" and phase != P.DRINK:
		# Cups only count once they're raised for the toast.
		kind = "miss"
		victim = -1
	if kind == "cup" and victim >= 0:
		saved = _rules.spill(victim, s)
		spilled = true
	elif kind == "head" and victim >= 0 and _rules.is_alive(victim):
		_fun_add(s, "hits")
		_fun_add(victim, "faces")
		if phase == P.DRINK:
			# Knocked over mid-toast: the raised cup goes flying.
			saved = _rules.spill(victim, s)
			spilled = true
	if spilled:
		_fun_add(s, "spills")
		if saved:
			_fun_add(s, "saves")
	_emit({"type": "cake", "seat": s, "to": target, "seed": _rng.randi(), "hit": kind, "victim": victim,
		"spilled": spilled, "ghost": ghost})
	if saved:
		var title := "GHOST SAVE!" if ghost else ("SAVED YOURSELF!" if victim == s else "CAKE SAVE!")
		_emit({"type": "moments", "list": [{"title": title, "sub": "%s knocked a DEADLY cup out of %s's hands" % [_nm(s), _nm(victim) if victim != s else "their own"]}]})
	_push(float(public.get("total", _timer)))


@rpc("any_peer", "unreliable")
func _rq_emote(emote: int) -> void:
	if hosting() and emote >= 0 and emote < Defs.EMOTES.size():
		var s := _sender_seat()
		if s >= 0:
			_emit({"type": "emote", "seat": s, "emote": emote})


# ---------------------------------------------------------------- actions (host)

func _do_pour(s: int, card_index: int, target: int) -> void:
	if s < 0:
		return
	var hand: Array = _rules.seats[s]["hand"]
	var k: int = hand[card_index] if card_index >= 0 and card_index < hand.size() else -1
	if _rules.pour(s, card_index, target):
		# Everyone hears THAT you poured, never where (it's dark).
		_emit({"type": "pour", "seat": s})
		_emit_private(s, {"type": "pour_mine", "k": k, "target": target})
		_push(float(public.get("total", _timer)))
	else:
		_emit_private(s, {"type": "error", "text": "You can't pour there."})


## Who may still say their last words this meeting (poisoned at this round's toast, once).
func can_last_words(seat: int) -> bool:
	return phase == P.TALK and seat >= 0 and seat < Session.seat_count() and not bool(seat_info(seat).get("alive", true)) \
		and not bool(seat_info(seat).get("ejected", false)) and int(public.get("round", 0)) == int(public.get("died_round_%d" % seat, -1)) \
		and not (public.get("last_words_used", []) as Array).has(seat)


func _do_claim(s: int, claim: Dictionary) -> void:
	if s < 0:
		return
	var last := false
	if not _rules.is_alive(s):
		# The freshly poisoned get ONE line (their last words) at this meeting; other ghosts stay quiet.
		if phase != P.TALK or _rules.seats[s]["ejected"] or int(_rules.seats[s]["died_round"]) != _rules.round_no or _last_words.has(s):
			return
		_last_words[s] = true
		last = true
	var kind := StringName(str(claim.get("kind", "")))
	if not Defs.CLAIMS.has(kind):
		return
	var c := {"type": "claim", "seat": s, "kind": kind, "a": int(claim.get("a", -1)), "b": int(claim.get("b", -1)),
		"k": int(claim.get("k", -1)), "smell": String(claim.get("smell", "clean"))}
	if c["a"] < 0 or c["a"] >= _rules.seat_count() or (kind in [&"saw", &"watch"] and (c["b"] < 0 or c["b"] >= _rules.seat_count())):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_claim_ready.get(s, 0.0)):
		return
	_claim_ready[s] = now + 1.2 / speed
	c["last"] = last
	_emit(c)
	if last:
		_push(_timer)
	for b: int in _bots:
		(_bots[b] as BotBrain).hear(c)


func _do_vote(s: int, target: int) -> void:
	if s >= 0 and _rules.vote(s, target):
		_emit({"type": "voted", "seat": s})
		_push(float(public.get("total", _timer)))


func _do_item(s: int, item_index: int, targets: Array) -> void:
	if s < 0 or _resolving:
		return
	var clean: Array = []
	for t: Variant in targets:
		clean.append(int(t))
	var items: Array = _rules.seats[s]["items"]
	var item: int = items[item_index] if item_index >= 0 and item_index < items.size() else -1
	var err := _rules.choose_item(s, item_index, clean)
	if err != "":
		_emit_private(s, {"type": "error", "text": err})
		return
	_emit({"type": "locked", "seat": s})
	_emit_private(s, {"type": "locked_mine", "item": item, "targets": clean})
	_push(_timer)


func _do_ready(s: int) -> void:
	if s >= 0 and _rules.is_alive(s) and not _rules.seats[s]["ready"]:
		_rules.seats[s]["ready"] = true
		_emit({"type": "ready", "seat": s})
		_push(float(public.get("total", _timer)))


func _do_rattle(s: int, target: int) -> void:
	if s >= 0 and _rules.rattle(s, target):
		_emit({"type": "rattle", "seat": s, "target": target})
		_round_log.append({"type": "rattle", "seat": s, "target": target})
		_push(float(public.get("total", _timer)))


# ---------------------------------------------------------------- bots

func _schedule_bots_pour() -> void:
	var t := float(_rules.rules["pour_time"])
	for s: int in _bots:
		if _rules.is_alive(s):
			_bot_wait[s] = _rng.randf_range(1.5, maxf(2.0, t * 0.35))


func _schedule_bot_items() -> void:
	for s: int in _bots:
		if _rules.is_alive(s) and not _rules.seats[s]["item_done"]:
			_bot_wait[s] = _rng.randf_range(1.0, 4.0)


func _schedule_bot_turn() -> void:
	pass


## During the toast bots may try to knock a cup away: their own if they fear it, or (as a ghost,
## who can see inside the cups) a deadly one.
func _schedule_bots_drink() -> void:
	for s: int in _bots:
		if _rng.randf() < (0.55 if _rules.is_alive(s) else 0.7):
			_bot_wait[s] = _rng.randf_range(0.6, DRINK_TIME * 0.7)


## A bot's aim: a point near a cup or a head (the probe knows where they are), with some wobble.
func _bot_throw(s: int, want_cup: bool, target_seat: int) -> void:
	if world_probe == null or not is_instance_valid(world_probe):
		return
	var p: Vector3 = world_probe.call(&"cup_point" if want_cup else &"head_point", target_seat)
	var wobble := 0.32 if want_cup else 0.35
	p += Vector3(_rng.randf_range(-wobble, wobble), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-wobble, wobble))
	_throw(s, p)


func _tick_bots(dt: float) -> void:
	for s: int in _bots.keys():
		var b: BotBrain = _bots[s]
		if _bot_chatter.has(s) and phase == P.TALK and _rules.is_alive(s):
			_bot_chatter[s] -= dt
			if _bot_chatter[s] <= 0.0:
				_bot_chatter[s] = b.claim_delay(float(_rules.rules["talk_time"]))
				var claim := b.next_claim(_rules.private_state(s), _rules.public_state())
				if not claim.is_empty():
					_do_claim(s, claim)
				elif _rng.randf() < 0.3:
					_emit({"type": "emote", "seat": s, "emote": b.chatter_emote(_rules.private_state(s), _rules.public_state())})
				if int(b.get("_claimed")) >= 5:
					_bot_chatter.erase(s)
		if not _bot_wait.has(s):
			continue
		_bot_wait[s] -= dt
		if _bot_wait[s] > 0.0:
			continue
		_bot_wait.erase(s)
		var pub := _rules.public_state()
		var priv := _rules.private_state(s)
		match phase:
			P.POUR:
				if _rules.is_alive(s) and not _rules.seats[s]["poured"]:
					var sv := b.choose_serve(priv, pub)
					if not sv.is_empty():
						_do_pour(s, int(sv["index"]), int(sv["target"]))
			P.ITEMS:
				if not _resolving and _rules.is_alive(s) and not _rules.seats[s]["item_done"]:
					var choice := b.choose_item(priv, pub)
					if choice.is_empty():
						_rules.pass_turn(s)
						_emit({"type": "pass", "seat": s})
						_push(_timer)
					else:
						_do_item(s, choice["index"], choice["targets"])
			P.TALK:
				if _rules.is_alive(s):
					_do_ready(s)
			P.VOTE:
				if _rules.is_alive(s) and not _rules.seats[s]["voted"]:
					_do_vote(s, b.choose_vote(pub))
				elif int(_rules.seats[s]["rattles"]) > 0:
					var t := b.choose_rattle(priv, pub)
					if t >= 0:
						_do_rattle(s, t)
					_bot_wait[s] = _rng.randf_range(4.0, 12.0)
			P.DRINK:
				if _rules.is_alive(s):
					if b.fears_own_cup(pub):
						_bot_throw(s, true, s)
					else:
						# Chaos: bonk a rival mid-toast so they drop their cup.
						var others := _rules.alive_seats()
						others.erase(s)
						if not others.is_empty():
							_bot_throw(s, false, others[_rng.randi_range(0, others.size() - 1)])
				else:
					var t := b.choose_rattle(priv, pub)
					if t >= 0:
						_bot_throw(s, true, t)
