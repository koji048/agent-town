## Costume definitions + persistence for the crew.
## Slots: class model, headgear, right hand, left hand, bracers, cape.
## Two presets: Office (default) and Adventure (classic Ragnarok party).
class_name Costumes

const SAVE_PATH := "user://costumes.json"

const CLASSES := ["Knight", "Mage", "Rogue", "Rogue_Hooded", "Barbarian"]

## Headgear: "class" = the model's built-in helmet/hat/hood, others are
## procedural office gear built by the agent.
const HEADGEAR := ["class", "none", "cap", "headset", "glasses", "party_hat", "crown"]

## Hand items: KayKit item meshes (assets/models/items) or "none".
const RIGHT_HAND := ["none", "mug_full", "smokebomb", "wand", "dagger", "sword_1handed", "axe_1handed", "staff"]
const LEFT_HAND := ["none", "spellbook_closed", "spellbook_open", "mug_full", "smokebomb", "shield_round", "shield_badge", "shield_square"]

const OFFICE_PRESET := {
	"director":   {"class": "Knight",       "headgear": "glasses", "right": "mug_full",  "left": "spellbook_closed", "bracers": false, "cape": false},
	"researcher": {"class": "Mage",         "headgear": "cap",     "right": "wand",      "left": "spellbook_open",   "bracers": false, "cape": false},
	"writer":     {"class": "Rogue_Hooded", "headgear": "class",   "right": "none",      "left": "spellbook_closed", "bracers": false, "cape": false},
	"editor":     {"class": "Rogue",        "headgear": "headset", "right": "none",      "left": "none",             "bracers": true,  "cape": false},
	"publisher":  {"class": "Barbarian",    "headgear": "cap",     "right": "mug_full",  "left": "none",             "bracers": false, "cape": false},
}

const ADVENTURE_PRESET := {
	"director":   {"class": "Knight",       "headgear": "class", "right": "sword_1handed", "left": "shield_badge", "bracers": true, "cape": true},
	"researcher": {"class": "Mage",         "headgear": "class", "right": "staff",         "left": "spellbook_open", "bracers": false, "cape": true},
	"writer":     {"class": "Rogue_Hooded", "headgear": "class", "right": "dagger",        "left": "smokebomb", "bracers": true, "cape": true},
	"editor":     {"class": "Rogue",        "headgear": "class", "right": "dagger",        "left": "none", "bracers": true, "cape": true},
	"publisher":  {"class": "Barbarian",    "headgear": "class", "right": "axe_1handed",   "left": "shield_round", "bracers": true, "cape": false},
}


static func load_all() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary:
			return data
	return OFFICE_PRESET.duplicate(true)


static func save_all(costumes: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(costumes, "  "))
		f.close()


static func label_for(value: String) -> String:
	return value.capitalize().replace("_", " ")
