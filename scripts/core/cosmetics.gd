class_name Cosmetics
extends RefCounted
## Everything a guest can unlock: hats, teacups, death animations, skins and titles.
## `price` in coins (0 = free), `level` = player level needed before it can be bought.

const HATS := {
	&"none": {"name": "Bare head", "price": 0, "level": 1},
	&"top_hat": {"name": "Top Hat", "price": 0, "level": 1},
	&"bowler": {"name": "Bowler", "price": 80, "level": 1},
	&"party": {"name": "Party Cone", "price": 60, "level": 1},
	&"bonnet": {"name": "Sunday Bonnet", "price": 120, "level": 2},
	&"fez": {"name": "Fez", "price": 150, "level": 2},
	&"flower_crown": {"name": "Flower Crown", "price": 200, "level": 3},
	&"witch": {"name": "Witch's Hat", "price": 260, "level": 4},
	&"teacup": {"name": "Teacup Hat", "price": 320, "level": 5},
	&"crown": {"name": "Royal Crown", "price": 500, "level": 7},
	&"beret": {"name": "Artist's Beret", "price": 90, "level": 1},
	&"chef": {"name": "Chef's Toque", "price": 140, "level": 2},
	&"bunny": {"name": "Bunny Ears", "price": 180, "level": 2},
	&"cat": {"name": "Kitty Ears", "price": 180, "level": 2},
	&"pirate": {"name": "Pirate Tricorn", "price": 240, "level": 3},
	&"propeller": {"name": "Propeller Cap", "price": 260, "level": 4},
	&"viking": {"name": "Viking Helmet", "price": 340, "level": 5},
	&"halo": {"name": "Halo", "price": 450, "level": 6},
	&"cloche": {"name": "Cake Dome", "price": 550, "level": 8},
}

## body / rim / tea colours.
const CUPS := {
	&"porcelain": {"name": "Blue Willow", "price": 0, "level": 1, "body": Color("f4f1ea"), "rim": Color("2e5f9a")},
	&"rose": {"name": "Rose Garden", "price": 70, "level": 1, "body": Color("f6d9dc"), "rim": Color("c0506a")},
	&"mint": {"name": "Mint Julep", "price": 70, "level": 1, "body": Color("d4efe1"), "rim": Color("3f8f6a")},
	&"midnight": {"name": "Midnight", "price": 140, "level": 2, "body": Color("252a44"), "rim": Color("c9b26b")},
	&"frog": {"name": "Toad Hall", "price": 160, "level": 3, "body": Color("7fae4a"), "rim": Color("3a5c1d")},
	&"gold": {"name": "Gilded", "price": 300, "level": 4, "body": Color("fbf4dd"), "rim": Color("d9a531")},
	&"skull": {"name": "Memento Mori", "price": 380, "level": 5, "body": Color("1b1b1b"), "rim": Color("e8e2d2")},
	&"royal": {"name": "Royal Doulton", "price": 520, "level": 7, "body": Color("4b2a6b"), "rim": Color("f0c75a")},
}

const DEATHS := {
	&"swoon": {"name": "The Swoon", "price": 0, "level": 1, "desc": "Clutch the pearls, flop backwards."},
	&"keel": {"name": "Face in the Cake", "price": 0, "level": 1, "desc": "Straight into the table. Cups everywhere."},
	&"stagger": {"name": "The Wobbler", "price": 120, "level": 2, "desc": "Spins, wobbles, crumples."},
	&"monologue": {"name": "Last Words", "price": 200, "level": 3, "desc": "A dramatic final speech, then down."},
	&"spin": {"name": "Pirouette", "price": 260, "level": 4, "desc": "Launched into a spin like a top."},
	&"confetti": {"name": "Confetti Pop", "price": 400, "level": 6, "desc": "Goes out with a bang and a shower of confetti."},
	&"ascend": {"name": "Ascension", "price": 600, "level": 8, "desc": "The body floats off to the great tea room in the sky."},
	&"yeet": {"name": "The Yeet", "price": 800, "level": 9, "desc": "Blasted clean across the room."},
}

## Bean colours: body, then the collar / cheeks accent.
const SKINS := {
	&"cream": {"name": "Buttermilk", "price": 0, "level": 1, "body": Color("ffe3b8"), "accent": Color("ff8fab")},
	&"mint": {"name": "Peppermint", "price": 0, "level": 1, "body": Color("8ee3c0"), "accent": Color("2f9e74")},
	&"berry": {"name": "Raspberry", "price": 0, "level": 1, "body": Color("ff6f91"), "accent": Color("ffd166")},
	&"sky": {"name": "Blue Moon", "price": 60, "level": 1, "body": Color("7cc6fe"), "accent": Color("ffffff")},
	&"lemon": {"name": "Lemon Curd", "price": 60, "level": 1, "body": Color("ffe066"), "accent": Color("ff7b54")},
	&"grape": {"name": "Grape Jelly", "price": 120, "level": 2, "body": Color("a78bfa"), "accent": Color("fde68a")},
	&"tangerine": {"name": "Marmalade", "price": 120, "level": 2, "body": Color("ff9f43"), "accent": Color("5f27cd")},
	&"matcha": {"name": "Matcha", "price": 180, "level": 3, "body": Color("9bc53d"), "accent": Color("fff5cc")},
	&"earl": {"name": "Earl Grey", "price": 240, "level": 4, "body": Color("8d99ae"), "accent": Color("ef233c")},
	&"choc": {"name": "Hot Cocoa", "price": 300, "level": 5, "body": Color("8b5e3c"), "accent": Color("ffd6a5")},
	&"gold": {"name": "Golden Tip", "price": 600, "level": 7, "body": Color("f4c430"), "accent": Color("ffffff")},
	&"lavender": {"name": "Lavender", "price": 60, "level": 1, "body": Color("c7b8ff"), "accent": Color("7a5cff")},
	&"coral": {"name": "Coral Reef", "price": 90, "level": 1, "body": Color("ff8577"), "accent": Color("2ec4b6")},
	&"bubblegum": {"name": "Bubblegum", "price": 120, "level": 2, "body": Color("ffb3de"), "accent": Color("40c4ff")},
	&"slate": {"name": "Midnight Oil", "price": 200, "level": 3, "body": Color("4b5d8a"), "accent": Color("ffd166")},
	&"cherry": {"name": "Black Cherry", "price": 260, "level": 4, "body": Color("8e1f3f"), "accent": Color("ffe3ec")},
	&"snow": {"name": "Snowdrop", "price": 320, "level": 5, "body": Color("f4f7ff"), "accent": Color("7cc6fe")},
}

## Face accessories.
const FACES := {
	&"none": {"name": "Bare face", "price": 0, "level": 1},
	&"moustache": {"name": "Handlebar Moustache", "price": 0, "level": 1},
	&"monocle": {"name": "Monocle", "price": 90, "level": 1},
	&"glasses": {"name": "Round Specs", "price": 90, "level": 1},
	&"blush": {"name": "Rosy Cheeks", "price": 60, "level": 1},
	&"nose": {"name": "Clown Nose", "price": 150, "level": 2},
	&"shades": {"name": "Cool Shades", "price": 220, "level": 3},
	&"beard": {"name": "Wizard Beard", "price": 320, "level": 5},
	&"freckles": {"name": "Freckles", "price": 50, "level": 1},
	&"lipstick": {"name": "Ruby Lips", "price": 80, "level": 1},
	&"plaster": {"name": "Sticking Plaster", "price": 110, "level": 2},
	&"eyepatch": {"name": "Eyepatch", "price": 200, "level": 3},
	&"pipe": {"name": "Bubble Pipe", "price": 260, "level": 4},
}

## Body shapes: belly width and eye size.
const SHAPES := {
	&"classic": {"name": "Classic Bean", "price": 0, "level": 1, "belly": 1.0, "eyes": 1.0},
	&"round": {"name": "Dumpling", "price": 0, "level": 1, "belly": 1.14, "eyes": 1.04},
	&"slim": {"name": "String Bean", "price": 0, "level": 1, "belly": 0.9, "eyes": 1.08},
	&"stout": {"name": "Teapot", "price": 80, "level": 1, "belly": 1.22, "eyes": 0.94},
	&"sprout": {"name": "Sprout", "price": 120, "level": 2, "belly": 0.86, "eyes": 1.2},
}

const EYES := {
	&"classic": {"name": "Googly", "price": 0, "level": 1},
	&"lashes": {"name": "Long Lashes", "price": 0, "level": 1},
	&"sleepy": {"name": "Sleepy", "price": 60, "level": 1},
	&"sparkle": {"name": "Starry-Eyed", "price": 120, "level": 2},
	&"beady": {"name": "Beady", "price": 120, "level": 2},
	&"suspicious": {"name": "Suspicious", "price": 180, "level": 3},
}

const HAIRDOS := {
	&"tuft": {"name": "Tuft", "price": 0, "level": 1},
	&"side_part": {"name": "Kiss Curl", "price": 0, "level": 1},
	&"bun": {"name": "Bun", "price": 0, "level": 1},
	&"curls": {"name": "Curls", "price": 0, "level": 1},
	&"bald": {"name": "Leaf Sprout", "price": 0, "level": 1},
	&"long": {"name": "Side Puffs", "price": 0, "level": 1},
	&"pigtails": {"name": "Pigtails", "price": 90, "level": 1},
	&"mohawk": {"name": "Mohawk", "price": 150, "level": 2},
	&"afro": {"name": "Big Curls", "price": 200, "level": 3},
	&"none": {"name": "Smooth", "price": 0, "level": 1},
}

const DYES := {
	&"brown": {"name": "Chestnut", "price": 0, "level": 1, "color": Color("3b2416")},
	&"black": {"name": "Liquorice", "price": 0, "level": 1, "color": Color("1d1a1f")},
	&"blonde": {"name": "Honey", "price": 0, "level": 1, "color": Color("e8b84f")},
	&"ginger": {"name": "Ginger", "price": 0, "level": 1, "color": Color("b8452a")},
	&"silver": {"name": "Silver Fox", "price": 60, "level": 1, "color": Color("c9c9d4")},
	&"plum": {"name": "Plum", "price": 60, "level": 1, "color": Color("5a3a7a")},
	&"pink": {"name": "Candyfloss", "price": 100, "level": 2, "color": Color("ff7eb6")},
	&"teal": {"name": "Peacock", "price": 100, "level": 2, "color": Color("1fb5a8")},
	&"rainbow": {"name": "Sherbet", "price": 250, "level": 4, "color": Color("ffb000")},
}

## Collar accessories, in the colour's accent colour.
const COLLARS := {
	&"bowtie": {"name": "Bow Tie", "price": 0, "level": 1},
	&"waistcoat": {"name": "Ruffle Collar", "price": 0, "level": 1},
	&"dress": {"name": "Pearl Necklace", "price": 0, "level": 1},
	&"cardigan": {"name": "Cosy Scarf", "price": 0, "level": 1},
	&"tie": {"name": "Necktie", "price": 70, "level": 1},
	&"rose": {"name": "Buttonhole Rose", "price": 110, "level": 2},
	&"medal": {"name": "Medal of Tea", "price": 200, "level": 3},
	&"cape": {"name": "Villain Cape", "price": 320, "level": 5},
}

const PATTERNS := {
	&"none": {"name": "Plain", "price": 0, "level": 1},
	&"spots": {"name": "Polka Dots", "price": 80, "level": 1},
	&"belly": {"name": "Tummy Patch", "price": 80, "level": 1},
	&"stripes": {"name": "Humbug Stripes", "price": 150, "level": 2},
	&"heart": {"name": "Big Heart", "price": 180, "level": 3},
	&"stars": {"name": "Starry Night", "price": 260, "level": 4},
}

## Titles unlock by lifetime stats (or level) and are free to wear.
const TITLES := {
	&"newcomer": {"name": "Newcomer", "stat": &"", "need": 0},
	&"taster": {"name": "Tea Taster", "stat": &"matches", "need": 3},
	&"survivor": {"name": "Survivor", "stat": &"rounds_survived", "need": 10},
	&"poisoner": {"name": "Cold Blooded", "stat": &"kills", "need": 5},
	&"nose": {"name": "Nose of the Year", "stat": &"sniffs", "need": 10},
	&"toastmaster": {"name": "Toastmaster", "stat": &"toasts", "need": 10},
	&"sleight": {"name": "Sleight of Hand", "stat": &"swaps", "need": 15},
	&"poltergeist": {"name": "Poltergeist", "stat": &"rattles", "need": 25},
	&"untouchable": {"name": "The Untouchable", "stat": &"wins", "need": 5},
	&"butler": {"name": "Mastermind", "stat": &"butler_wins", "need": 1},
	&"sharpshooter": {"name": "Sharpshooter", "stat": &"cake_hits", "need": 15},
	&"angel": {"name": "Guardian Angel", "stat": &"saves", "need": 3},
	&"host": {"name": "Hostess with the Mostest", "stat": &"level", "need": 5},
	&"dowager": {"name": "Dowager", "stat": &"level", "need": 10},
}

const CATEGORIES := {&"hat": HATS, &"face": FACES, &"cup": CUPS, &"death": DEATHS, &"skin": SKINS,
	&"shape": SHAPES, &"eyes": EYES, &"hair": HAIRDOS, &"dye": DYES, &"collar": COLLARS, &"pattern": PATTERNS}

## Everything a look carries (sent to the other players).
const LOOK_KEYS := [&"hat", &"face", &"cup", &"death", &"skin", &"shape", &"eyes", &"hair", &"dye", &"collar", &"pattern", &"title"]

const DEFAULT_EQUIP := {&"hat": &"top_hat", &"face": &"moustache", &"cup": &"porcelain", &"death": &"swoon", &"skin": &"cream", &"title": &"newcomer",
	&"shape": &"classic", &"eyes": &"classic", &"hair": &"tuft", &"dye": &"brown", &"collar": &"bowtie", &"pattern": &"none"}


static func entry(category: StringName, id: StringName) -> Dictionary:
	if category == &"title":
		return TITLES.get(id, TITLES[&"newcomer"])
	var cat: Dictionary = CATEGORIES.get(category, {})
	return cat.get(id, cat.get(DEFAULT_EQUIP.get(category, &""), {}))


static func title_name(id: Variant) -> String:
	return String(TITLES.get(StringName(str(id)), TITLES[&"newcomer"])["name"])


## Random cosmetics for a bot (anything, so the table looks lively).
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var pick := func(d: Dictionary) -> StringName:
		var keys := d.keys()
		return keys[rng.randi_range(0, keys.size() - 1)]
	var t: Array = TITLES.keys()
	var out := {"title": t[rng.randi_range(0, t.size() - 1)]}
	for c: StringName in CATEGORIES:
		out[String(c)] = pick.call(CATEGORIES[c])
	return out


## A random look from what you own (the wardrobe's SURPRISE ME).
static func random_owned(rng: RandomNumberGenerator, owns: Callable, keep: Dictionary) -> Dictionary:
	var out := keep.duplicate()
	for c: StringName in CATEGORIES:
		if c == &"death" or c == &"cup":
			continue
		var mine: Array = []
		for id: StringName in CATEGORIES[c]:
			if owns.call(c, id):
				mine.append(id)
		if not mine.is_empty():
			out[String(c)] = mine[rng.randi_range(0, mine.size() - 1)]
	return out
