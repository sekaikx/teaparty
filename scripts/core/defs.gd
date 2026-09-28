class_name Defs
extends RefCounted
## Shared constants: ingredients, items, phases, modes, rooms, emotes and default lobby rules.

enum Ingredient { NOTHING, POISON, ANTIDOTE, SUGAR }
enum Item { SWAP, SNIFF, TOAST, PEEK, INSPECT, PROTECT, LEAVES, FRESH, TIDY }
## Round order: DEAL > POUR (serve in the dark) > ITEMS > DRINK (the toast) > REVEAL > TALK (the
## meeting) > VOTE > EJECT. New phases are appended so the numbers of the old ones never change.
enum Phase { LOBBY, INTRO, DEAL, POUR, ITEMS, TALK, DRINK, REVEAL, MATCH_END, VOTE, EJECT }

const INGREDIENTS := {
	Ingredient.NOTHING: {"name": "Plain", "short": "Plain", "color": Color("b8a88a"),
		"desc": "Just tea. Harmless, but it gives you an alibi."},
	Ingredient.POISON: {"name": "Poison", "short": "Poison", "color": Color("5f8a2c"),
		"desc": "One drop and the drinker collapses (unless an antidote is in the cup too)."},
	Ingredient.ANTIDOTE: {"name": "Antidote", "short": "Antidote", "color": Color("2e6a93"),
		"desc": "Cancels one poison in the same cup."},
	Ingredient.SUGAR: {"name": "Sugar", "short": "Sugar", "color": Color("e9e1d0"),
		"desc": "Harmless, but a sniff of a sugared cup tells nothing."},
}

const ITEMS := {
	Item.SWAP: {"name": "Swap", "targets": 2, "target": &"cup",
		"desc": "Swap two cups on the table. Everyone sees it (so you'll have to explain yourself)."},
	Item.SNIFF: {"name": "Sniff", "targets": 1, "target": &"cup",
		"desc": "Sniff a cup: you alone learn if it's poisoned right now (sugar hides it)."},
	Item.TOAST: {"name": "Force a Toast", "targets": 1, "target": &"guest",
		"desc": "Raise a toast to a guest: they must drink their cup right now (after the swaps)."},
	Item.PEEK: {"name": "Watch", "targets": 1, "target": &"guest",
		"desc": "Watch a guest: you alone learn whose cup they poured into. Catch a liar."},
	Item.LEAVES: {"name": "Tea Leaves", "targets": 1, "target": &"cup",
		"desc": "Read the leaves in a cup: you alone learn how many guests poured into it (not what)."},
	Item.FRESH: {"name": "Fresh Cup", "targets": 1, "target": &"cup",
		"desc": "Ring for the butler: one cup is taken away and a fresh one poured. Whatever was in it is gone. Everyone sees you ring."},
	# Role cards: dealt every round to the Inspector and the Physician, on top of their normal
	# item, and played in secret (nobody sees who used them).
	Item.INSPECT: {"name": "Inspect", "targets": 1, "target": &"guest", "role": true,
		"desc": "INSPECTOR: examine a guest's hands. Poison leaves a trace on whoever poured it THIS round."},
	Item.PROTECT: {"name": "Watch Over", "targets": 1, "target": &"guest", "role": true,
		"desc": "PHYSICIAN: keep your smelling salts ready for a guest. If they're poisoned this round, you bring them round."},
	Item.TIDY: {"name": "Tidy Up", "targets": 2, "target": &"cup", "role": true,
		"desc": "BUTLER: quietly swap two cups. Everyone sees them move, but nobody knows who did it."},
}

## Party twists: one is announced at the start of most rounds (lobby rule "twists").
const TWISTS := {
	&"blackout": {"name": "BLACKOUT", "desc": "The candles are out: nobody glimpses anything this round."},
	&"full_moon": {"name": "FULL MOON", "desc": "Moonlight through the curtains: everyone glimpses a pour this round."},
	&"favours": {"name": "PARTY FAVOURS", "desc": "Everyone gets an extra item this round."},
	&"gossip": {"name": "GOSSIP", "desc": "The butler saw something: one true pour is told to the whole table."},
	&"sugar_rush": {"name": "SUGAR RUSH", "desc": "The trays are full of sugar: sniffing tells you almost nothing."},
}

## Daily challenges: one a day (picked by the date), played from the main menu with bots.
## "rules" are lobby-rule overrides; "bots" is how many bots join you.
const DAILY := [
	{"id": "swap_meet", "name": "Swap Meet", "desc": "The only items are SWAPS, and everyone gets two. Keep an eye on your cup!",
		"bots": 5, "rules": {"items_enabled": [Item.SWAP], "items_per_round": 2, "max_items": 2}},
	{"id": "suspects", "name": "Everyone's a Suspect", "desc": "Nobody glimpses anything, ever. Only items and lies to go on.",
		"bots": 5, "rules": {"glimpse_chance": 0.0}},
	{"id": "nose", "name": "The Nose Knows", "desc": "The only item is SNIFF. Smell your way to the poisoner.",
		"bots": 5, "rules": {"items_enabled": [Item.SNIFF], "items_per_round": 1}},
	{"id": "full_moon", "name": "Full Moon Fever", "desc": "A full moon every round: everyone always glimpses a pour. Night party.",
		"bots": 6, "rules": {"force_twist": "full_moon", "night": true}},
	{"id": "gossip", "name": "Gossip Night", "desc": "The butler gossips every round: one true pour is told to everyone.",
		"bots": 5, "rules": {"force_twist": "gossip", "room": &"banquet"}},
	{"id": "sugar", "name": "Sugar Coated", "desc": "A sugar rush every round: sniffs are useless. Trust the leaves.",
		"bots": 5, "rules": {"force_twist": "sugar_rush", "items_enabled": [Item.LEAVES, Item.PEEK, Item.SWAP]}},
	{"id": "big_party", "name": "The Big Party", "desc": "Eight guests, two poisoners, the Butler and every role at the Royal Banquet.",
		"bots": 7, "rules": {"room": &"banquet", "max_players": 8}},
	{"id": "glasshouse", "name": "Murder in the Glasshouse", "desc": "A night party among the ferns, with a blackout every round.",
		"bots": 5, "rules": {"room": &"greenhouse", "night": true, "force_twist": "blackout"}},
	{"id": "fresh", "name": "Fresh Cups Only", "desc": "Everyone gets a FRESH CUP every round. Can the poisoner get one through?",
		"bots": 5, "rules": {"items_enabled": [Item.FRESH], "items_per_round": 1}},
]


## Today's challenge (the same for everyone on the same date).
static func daily_today() -> Dictionary:
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	return DAILY[day % DAILY.size()]


## The special innocent roles, like Mafia's detective and doctor (but at a tea party).
const ROLES := {
	&"guest": {"name": "Guest", "desc": "An innocent guest."},
	&"poisoner": {"name": "Poisoner", "desc": "The murderer."},
	&"inspector": {"name": "The Inspector", "card": Item.INSPECT, "min_players": 5,
		"desc": "A detective in a deerstalker. Each round, INSPECT one guest's hands: poison leaves a trace on whoever poured it this round. Share it at the meeting... but the poisoner can claim to be you."},
	&"butler": {"name": "The Butler", "card": Item.TIDY, "min_players": 7, "neutral": true,
		"desc": "On nobody's side. You win if you're still at the table when the party ends (whoever else wins). Each round you may secretly TIDY UP: swap two cups, and nobody knows it was you. Stir things up... but don't get voted out."},
	&"physician": {"name": "The Physician", "card": Item.PROTECT, "min_players": 6,
		"desc": "The family doctor. Each round, WATCH OVER one guest: if they drink poison, your smelling salts bring them round. Not the same guest twice in a row; yourself only once."},
}

const PHASE_NAMES := {
	Phase.LOBBY: "Lobby", Phase.INTRO: "The guests arrive", Phase.DEAL: "Dealing",
	Phase.POUR: "Serve", Phase.ITEMS: "Items", Phase.TALK: "Meeting",
	Phase.DRINK: "Toast", Phase.REVEAL: "The reveal", Phase.MATCH_END: "Party's over",
	Phase.VOTE: "Vote", Phase.EJECT: "Thrown out",
}

## Modes and rooms (all open to everyone; "level" is kept only for old saves).
const MODES := {
	&"classic": {"name": "Murder at Teatime", "level": 1, "desc": "A secret poisoner (two with 8 guests) is at the table. Find them and vote them out before they poison everyone."},
	&"hitlist": {"name": "Hit List", "level": 1, "desc": "Every poisoner has one secret target. Poison all the targets (from round 3 on, 4 with two poisoners) and the poisoners win. Each target is warned, and gets an extra item every round."},
	&"rivals": {"name": "Rival Poisoners", "level": 1, "desc": "6+ guests: TWO poisoners on different sides, each with a vial every round. They don't know each other. Last poisoner standing wins alone; the guests need both out."},
}

const ROOMS := {
	&"parlor": {"name": "The Parlour", "level": 1, "seats": 6, "desc": "Firelight, wallpaper and a round table."},
	&"garden": {"name": "Garden Party", "level": 3, "seats": 6, "desc": "Hedges, bunting and birdsong on the lawn."},
	&"banquet": {"name": "Royal Banquet", "level": 5, "seats": 8, "desc": "A candlelit hall and a long table for eight."},
	&"greenhouse": {"name": "The Glasshouse", "level": 1, "seats": 6, "desc": "A moonlit greenhouse: ferns, lanterns and fireflies under the glass."},
}

## Custom lobby rules are open to everyone (kept for old callers).
const CUSTOM_RULES_LEVEL := 1

const TEAM_NAMES := ["Earl Grey", "Darjeeling"]
const TEAM_COLORS := [Color("7c4596"), Color("c2702a")]

const DEFAULT_RULES := {
	"room": &"parlor",
	"mode": &"classic",
	"max_players": 6,
	"hand_size": 3,
	"pour_time": 25.0,
	"item_turn_time": 12.0,
	"talk_time": 60.0,
	"vote_time": 20.0,
	## How likely each guest is to glimpse one other guest's pour in the dark (-1 = by table size).
	"glimpse_chance": -1.0,
	"items_per_round": 1,
	"max_items": 2,
	"laced_round": 5,
	"max_rounds": 8,
	"poison_scale": 1.0,
	"ghost_rattles": 3,
	"ghosts_see_cups": false,
	"ghosts_talk_to_living": false,
	"helium": false,
	"night": false,
	"items_enabled": [Item.SWAP, Item.SNIFF, Item.PEEK, Item.LEAVES, Item.FRESH],
	## With two poisoners: do they know who the other one is?
	"partners_known": false,
	## A random twist most rounds (see TWISTS).
	"twists": true,
	## Special innocent roles (dealt when the table is big enough, see ROLES).
	"inspector": true,
	"physician": true,
	"butler": true,
}

## Emote wheel: label, speech bubble line, gesture (Guest.gesture) and a voice blip.
const EMOTES := [
	{"name": "Cheers!", "line": "Cheers!", "clip": &"cheer", "sound": &"voice_01"},
	{"name": "Not me!", "line": "It wasn't me!", "clip": &"no", "sound": &"voice_02"},
	{"name": "Accuse", "line": "YOU!!", "clip": &"point", "sound": &"voice_03"},
	{"name": "Hmm...", "line": "Hmmmm...", "clip": &"think", "sound": &"v_hmm"},
	{"name": "Trust me", "line": "Trust me :)", "clip": &"yes", "sound": &"voice_05"},
	{"name": "Please", "line": "PLEASE SPARE ME", "clip": &"plead", "sound": &"voice_02"},
	{"name": "Laugh", "line": "Tee hee hee!", "clip": &"laugh", "sound": &"v_giggle"},
	{"name": "Sip", "line": "*sips loudly*", "clip": &"sip", "sound": &"voice_04"},
	{"name": "Gasp!", "line": "*GASP*", "clip": &"shock", "sound": &"v_eek"},
	{"name": "How dare!", "line": "HOW DARE YOU!", "clip": &"point", "sound": &"v_wow"},
	{"name": "Oops", "line": "Oops...", "clip": &"shrug", "sound": &"v_oops"},
	{"name": "Yay!", "line": "YAAAY!", "clip": &"cheer", "sound": &"v_yay"},
]

const BOT_NAMES := [
	"Lady Marmalade", "Sir Crumpet", "Duchess Earl", "Colonel Scone", "Miss Bergamot",
	"Lord Biscuit", "Auntie Oolong", "Vicar Treacle", "Countess Chai", "Baron Jam",
	"Madame Lapsang", "Captain Kettle",
]


## Things you can SAY at the meeting (a button bar, for players not on voice and for bots).
## Any claim can be a lie.
const CLAIMS := {
	&"poured": "I poured %s into %s's cup.",
	&"saw": "I saw %s pour into %s's cup!",
	&"sniff": "I sniffed %s's cup: %s.",
	&"watch": "I watched %s: they poured into %s's cup!",
	&"sus": "It's %s! Vote %s!",
	&"clear": "%s is innocent, I'd bet on it.",
	&"inspect": "I'm the INSPECTOR: %s had %s hands!",
	&"protect": "I'm the PHYSICIAN: I watched over %s.",
	&"leaves": "I read the leaves in %s's cup: %d pours.",
}


## The words of a claim {kind, a, b, k, smell}, with `nm` turning a seat into a name.
static func claim_text(c: Dictionary, nm: Callable) -> String:
	match StringName(c.get("kind", "")):
		&"poured":
			var k := int(c.get("k", -1))
			return "I poured %s into %s's cup." % [ingredient_name(k).to_upper() if k >= 0 else "something", nm.call(int(c["a"]))]
		&"saw":
			return "I saw %s pour into %s's cup!" % [nm.call(int(c["a"])), nm.call(int(c["b"]))]
		&"sniff":
			var sm := String(c.get("smell", "clean"))
			return "I sniffed %s's cup: %s." % [nm.call(int(c["a"])), {"poison": "POISON", "clean": "it was clean", "sweet": "too sweet to tell"}.get(sm, sm)]
		&"watch":
			return "I watched %s: they poured into %s's cup!" % [nm.call(int(c["a"])), nm.call(int(c["b"]))]
		&"sus":
			return "It's %s! Vote %s!" % [nm.call(int(c["a"])), nm.call(int(c["a"]))]
		&"clear":
			return "%s is innocent, I'd bet on it." % nm.call(int(c["a"]))
		&"inspect":
			return "I'm the INSPECTOR: %s %s" % [nm.call(int(c["a"])), "had POISON on their hands!" if c.get("guilty", false) else "had clean hands this round."]
		&"protect":
			return "I'm the PHYSICIAN: I watched over %s." % nm.call(int(c["a"]))
		&"leaves":
			var n := int(c.get("k", 0))
			return "I read the leaves in %s's cup: %d pour%s." % [nm.call(int(c["a"])), n, "" if n == 1 else "s"]
	return "..."


static func ingredient_name(k: int) -> String:
	return INGREDIENTS[k]["name"] if INGREDIENTS.has(k) else "?"


static func role_name(r: StringName) -> String:
	return String(ROLES.get(r, {}).get("name", "Guest"))


static func is_role_card(k: int) -> bool:
	return bool(ITEMS.get(k, {}).get("role", false))


static func item_name(k: int) -> String:
	return ITEMS[k]["name"] if ITEMS.has(k) else "?"


static func default_rules() -> Dictionary:
	return DEFAULT_RULES.duplicate(true)
