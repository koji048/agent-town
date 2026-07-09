## Costume definitions + persistence for the crew.
## CHARACTER SETS (per the owner): the whole cast switches THEME as one
## — Office (Quaternius modern people) or Dungeon (KayKit adventurers)
## — then each character picks a look WITHIN the active set. Slots:
## class model, headgear, right/left hand, bracers, cape.
class_name Costumes

const SAVE_PATH := "user://costumes.json"
const SET_PATH := "user://charset.txt"

const SETS := {
	"office": {
		"label": "OFFICE",
		"char_h": 1.70,  # realistic bodies at metric adult height
		"classes": ["BusinessMan", "Casual", "Hoodie", "Punk", "Worker",
			"Farmer", "Beach", "SWAT"],
		"preset": {
			"director":   {"class": "BusinessMan", "headgear": "glasses", "right": "mug_full", "left": "none", "bracers": false, "cape": false},
			"researcher": {"class": "Casual",      "headgear": "cap",     "right": "none",     "left": "none", "bracers": false, "cape": false},
			"writer":     {"class": "Hoodie",      "headgear": "none",    "right": "none",     "left": "none", "bracers": false, "cape": false},
			"editor":     {"class": "Punk",        "headgear": "headset", "right": "none",     "left": "none", "bracers": false, "cape": false},
			"publisher":  {"class": "Worker",      "headgear": "cap",     "right": "mug_full", "left": "none", "bracers": false, "cape": false},
		},
	},
	"dungeon": {
		"label": "DUNGEON",
		"char_h": 1.35,  # chibi bodies read right a head shorter
		"classes": ["Knight", "Mage", "Rogue", "Rogue_Hooded", "Barbarian"],
		"preset": {
			"director":   {"class": "Knight",       "headgear": "class", "right": "sword_1handed", "left": "shield_badge",   "bracers": true,  "cape": true},
			"researcher": {"class": "Mage",         "headgear": "class", "right": "staff",         "left": "spellbook_open", "bracers": false, "cape": true},
			"writer":     {"class": "Rogue_Hooded", "headgear": "class", "right": "dagger",        "left": "smokebomb",      "bracers": true,  "cape": true},
			"editor":     {"class": "Rogue",        "headgear": "class", "right": "dagger",        "left": "none",           "bracers": true,  "cape": true},
			"publisher":  {"class": "Barbarian",    "headgear": "class", "right": "axe_1handed",   "left": "shield_round",   "bracers": true,  "cape": false},
		},
	},
}

## Headgear: "class" = the model's built-in helmet/hat/hood, others are
## procedural office gear built by the agent.
const HEADGEAR := ["class", "none", "cap", "headset", "glasses", "party_hat", "crown"]

## Hand items: KayKit item meshes (assets/models/items) or "none".
const RIGHT_HAND := ["none", "mug_full", "smokebomb", "wand", "dagger", "sword_1handed", "axe_1handed", "staff"]
const LEFT_HAND := ["none", "spellbook_closed", "spellbook_open", "mug_full", "smokebomb", "shield_round", "shield_badge", "shield_square"]


static func current_set() -> String:
	if FileAccess.file_exists(SET_PATH):
		var s := FileAccess.get_file_as_string(SET_PATH).strip_edges()
		if SETS.has(s):
			return s
	return "office"


static func save_set(s: String) -> void:
	var f := FileAccess.open(SET_PATH, FileAccess.WRITE)
	if f:
		f.store_string(s)
		f.close()


static func set_preset(s: String) -> Dictionary:
	return (SETS.get(s, SETS["office"])["preset"] as Dictionary)


static func set_classes(s: String) -> Array:
	return (SETS.get(s, SETS["office"])["classes"] as Array)


static func load_all() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary:
			return data
	return set_preset(current_set()).duplicate(true)


static func save_all(costumes: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(costumes, "  "))
		f.close()


static func label_for(value: String) -> String:
	return value.capitalize().replace("_", " ")
