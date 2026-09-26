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
const INTRO_TIME := 4.0
const DEAL_TIME := 2.5
const DRINK_TIME := 4.5
const REVEAL_TIME := 5.0
const REVEAL_PER_DEATH := 1.8
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


func is_my_turn() -> bool:
	return phase == P.ITEMS and int(public.get("turn", -1)) == my_seat and am_alive()


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
				_begin_items()
			elif _timer <= 0.0:
				for s in _rules.alive_seats():
					if not _rules.seats[s]["poured"]:
						var k := _rules.auto_pour(s)
						_emit({"type": "pour", "seat": s, "target": _rules.pour_target(s)})
						_emit_private(s, {"type": "auto_pour", "k": k})
				_begin_items()
		P.ITEMS:
			if _rules.items_done():
				_begin_talk()
			elif _timer <= 0.0:
				var s := _rules.current_turn()
				_emit({"type": "pass", "seat": s, "timeout": true})
				_rules.pass_turn(s)
				_next_turn()
		P.TALK:
			var all_ready := true
			for s in _rules.alive_seats():
				if not _rules.seats[s]["ready"]:
					all_ready = false
			if all_ready or _timer <= 0.0:
				_set_phase(P.DRINK, DRINK_TIME)
				_emit({"type": "countdown"})
		P.DRINK:
			if _timer <= 0.0:
				var drinks := _rules.drink_all()
				var deaths := 0
				for d in drinks:
					if d["died"]:
						deaths += 1
				_emit({"type": "drink_all", "drinks": drinks})
				_emit({"type": "reveal", "cups": _rules.reveal()})
				_set_phase(P.REVEAL, REVEAL_TIME + REVEAL_PER_DEATH * deaths)
		P.REVEAL:
			if _timer <= 0.0:
				var w := _pending_end
				if w.is_empty():
					w = _rules.check_winner(_rules.round_no >= int(_rules.rules["max_rounds"]))
				if w["over"]:
					_end_match(w)
				else:
					_start_round()


func _set_phase(p: int, seconds: float) -> void:
	phase = p
	_timer = seconds
	_push(seconds)


func _start_round() -> void:
	_rules.start_round()
	_pending_end = {}
	var pub := _rules.public_state()
	for s: int in _bots:
		(_bots[s] as BotBrain).new_round(pub)
	_emit({"type": "round", "round": _rules.round_no, "laced": _rules.laced})
	_set_phase(P.DEAL, DEAL_TIME)


func _begin_items() -> void:
	_rules.begin_items()
	if _rules.items_done():
		_begin_talk()
		return
	_set_phase(P.ITEMS, float(_rules.rules["item_turn_time"]))
	_schedule_bot_turn()


func _next_turn() -> void:
	if _pending_end.size() > 0:
		_set_phase(P.REVEAL, REVEAL_TIME)
		return
	if _rules.items_done():
		_begin_talk()
		return
	_timer = float(_rules.rules["item_turn_time"])
	_push(_timer)
	_schedule_bot_turn()


func _begin_talk() -> void:
	_set_phase(P.TALK, float(_rules.rules["talk_time"]))
	var talk := float(_rules.rules["talk_time"])
	for s: int in _bots:
		var b: BotBrain = _bots[s]
		if _rules.is_alive(s):
			_bot_wait[s] = b.ready_delay(talk)
			_bot_chatter[s] = _rng.randf_range(2.0, talk * 0.4)
		else:
			_bot_wait[s] = _rng.randf_range(3.0, talk * 0.6)


func _end_match(w: Dictionary) -> void:
	var seats_out: Array = []
	for s in _rules.seats:
		seats_out.append({"name": s["name"], "id": s["id"], "bot": s["bot"], "alive": s["alive"],
			"role": s["role"], "team": s["team"], "kills": s["kills"], "rounds_survived": s["rounds_survived"],
			"sniffs": s["sniffs"], "toasts": s["toasts"], "swaps": s["swaps"], "peeks": s["peeks"],
			"rattles_used": s["rattles_used"], "died_round": s["died_round"], "cos": s["cos"]})
	var res := {"winners": w["winners"], "reason": w["reason"], "seats": seats_out, "rounds": _rules.round_no,
		"mode": _rules.mode()}
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
	res["award"] = Profile.award(me, won, me.get("role", &"guest") == &"butler") if not me.is_empty() else {}
	match_over.emit(res)


# ---------------------------------------------------------------- sending

func _push(total: float = -1.0) -> void:
	var pub := _rules.public_state()
	pub["phase"] = phase
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


func request_pour(card_index: int) -> void:
	_call_host(&"_rq_pour", [card_index])


func request_spike(target: int) -> void:
	_call_host(&"_rq_spike", [target])


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


func _sender_seat() -> int:
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = _local_id()
	return _rules.seat_of_id(id) if _rules else -1


@rpc("any_peer", "reliable")
func _rq_pour(card_index: int) -> void:
	if hosting() and phase == P.POUR:
		_do_pour(_sender_seat(), card_index)


@rpc("any_peer", "reliable")
func _rq_spike(target: int) -> void:
	if hosting() and phase == P.POUR:
		_do_spike(_sender_seat(), target)


@rpc("any_peer", "reliable")
func _rq_item(item_index: int, targets: Array) -> void:
	if hosting() and phase == P.ITEMS:
		_do_item(_sender_seat(), item_index, targets)


@rpc("any_peer", "reliable")
func _rq_pass() -> void:
	if hosting() and phase == P.ITEMS:
		var s := _sender_seat()
		if _rules.pass_turn(s):
			_emit({"type": "pass", "seat": s})
			_next_turn()


@rpc("any_peer", "reliable")
func _rq_ready() -> void:
	if hosting() and phase == P.TALK:
		_do_ready(_sender_seat())


@rpc("any_peer", "reliable")
func _rq_rattle(target: int) -> void:
	if hosting() and phase in [P.ITEMS, P.TALK, P.POUR]:
		_do_rattle(_sender_seat(), target)


@rpc("any_peer", "unreliable")
func _rq_emote(emote: int) -> void:
	if hosting() and emote >= 0 and emote < Defs.EMOTES.size():
		var s := _sender_seat()
		if s >= 0:
			_emit({"type": "emote", "seat": s, "emote": emote})


# ---------------------------------------------------------------- actions (host)

func _do_pour(s: int, card_index: int) -> void:
	if s < 0:
		return
	var hand: Array = _rules.seats[s]["hand"]
	var k: int = hand[card_index] if card_index >= 0 and card_index < hand.size() else -1
	if _rules.pour(s, card_index):
		_emit({"type": "pour", "seat": s, "target": _rules.pour_target(s)})
		_emit_private(s, {"type": "pour_mine", "k": k, "target": _rules.pour_target(s)})
		_push(float(public.get("total", _timer)))


func _do_spike(s: int, target: int) -> void:
	if s >= 0 and _rules.spike(s, target):
		# Everyone hears a mysterious drip; only the butler knows where.
		_emit({"type": "spike_sound"})
		_emit_private(s, {"type": "spike_done", "target": target})
		_push(float(public.get("total", _timer)))


func _do_item(s: int, item_index: int, targets: Array) -> void:
	if s < 0:
		return
	var clean: Array = []
	for t: Variant in targets:
		clean.append(int(t))
	var res := _rules.use_item(s, item_index, clean)
	if not res["ok"]:
		_emit_private(s, {"type": "error", "text": res["error"]})
		return
	for ev: Dictionary in res["public"]:
		_emit(ev)
	for ev: Dictionary in res["private"]:
		_emit_private(s, ev)
	var w := _rules.check_winner()
	if w["over"]:
		_pending_end = w
	_next_turn()


func _do_ready(s: int) -> void:
	if s >= 0 and _rules.is_alive(s) and not _rules.seats[s]["ready"]:
		_rules.seats[s]["ready"] = true
		_emit({"type": "ready", "seat": s})
		_push(float(public.get("total", _timer)))


func _do_rattle(s: int, target: int) -> void:
	if s >= 0 and _rules.rattle(s, target):
		_emit({"type": "rattle", "seat": s, "target": target})
		_push(float(public.get("total", _timer)))


# ---------------------------------------------------------------- bots

func _schedule_bots_pour() -> void:
	var t := float(_rules.rules["pour_time"])
	for s: int in _bots:
		if _rules.is_alive(s):
			_bot_wait[s] = _rng.randf_range(1.5, maxf(2.0, t * 0.45))


func _schedule_bot_turn() -> void:
	var s := _rules.current_turn()
	if _bots.has(s):
		_bot_wait[s] = _rng.randf_range(1.2, 3.2)


func _tick_bots(dt: float) -> void:
	for s: int in _bots.keys():
		var b: BotBrain = _bots[s]
		if _bot_chatter.has(s) and phase == P.TALK and _rules.is_alive(s):
			_bot_chatter[s] -= dt
			if _bot_chatter[s] <= 0.0:
				_bot_chatter[s] = _rng.randf_range(6.0, 16.0)
				_emit({"type": "emote", "seat": s, "emote": b.chatter_emote(_rules.private_state(s), _rules.public_state())})
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
					var target := b.choose_spike(priv, pub)
					if target >= 0:
						_do_spike(s, target)
					_do_pour(s, b.choose_pour(priv, pub))
			P.ITEMS:
				if _rules.current_turn() == s:
					var choice := b.choose_item(priv, pub)
					if choice.is_empty():
						_rules.pass_turn(s)
						_emit({"type": "pass", "seat": s})
						_next_turn()
					else:
						_do_item(s, choice["index"], choice["targets"])
			P.TALK:
				if _rules.is_alive(s):
					_do_ready(s)
				elif int(_rules.seats[s]["rattles"]) > 0:
					var t := b.choose_rattle(priv, pub)
					if t >= 0:
						_do_rattle(s, t)
					_bot_wait[s] = _rng.randf_range(4.0, 12.0)
