## Agent memory streams + relationships (docs/CREATIVE_DIRECTION.md,
## pillar 2 — Smallville's architecture at 5-agent depth, heuristic
## edition: no embeddings, importance scored by event type, retrieval =
## recency x importance x keyword overlap). Persisted across sessions.
extends Node

const ROLES := ["director", "researcher", "writer", "editor", "publisher"]
const MAX_PER_AGENT := 220
const SAVE_PATH := "user://memories.json"
const REL_PATH := "user://relationships.json"

# memories[role] = Array of {t: float, text: String, imp: float}
var memories: Dictionary = {}
# affinity["writer|editor"] = 0.0..1.0 (0.5 neutral)
var affinity: Dictionary = {}
# global gossip cooldown (anti greeting-loop, a16z AI Town)
var last_gossip_at := 0.0


func _ready() -> void:
	for r in ROLES:
		memories[r] = []
	_load()


## Record an event into one agent's stream. imp 1..10.
func remember(role: String, text: String, imp: float = 4.0) -> void:
	if not memories.has(role):
		return
	memories[role].append({"t": Time.get_unix_time_from_system(), "text": text, "imp": imp})
	if memories[role].size() > MAX_PER_AGENT:
		memories[role] = memories[role].slice(memories[role].size() - MAX_PER_AGENT)
	_save()


## Record for every agent (shared events: shipping, all-hands).
func remember_all(text: String, imp: float = 5.0) -> void:
	for r in ROLES:
		memories[r].append({"t": Time.get_unix_time_from_system(), "text": text, "imp": imp})
	_save()


## Retrieval: top `k` memories scored by recency x importance x relevance.
func recall(role: String, query: String, k: int = 5) -> Array:
	var now := Time.get_unix_time_from_system()
	var q_tokens := _tokens(query)
	var scored: Array = []
	for m in memories.get(role, []):
		var hours := (now - float(m["t"])) / 3600.0
		var recency := exp(-hours / 48.0)
		var overlap := 0.0
		var m_tokens := _tokens(str(m["text"]))
		for t in q_tokens:
			if t in m_tokens:
				overlap += 1.0
		var relevance := overlap / maxf(float(q_tokens.size()), 1.0)
		scored.append([recency * 0.45 + float(m["imp"]) / 10.0 * 0.35 + relevance * 0.20, m])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for i in mini(k, scored.size()):
		out.append(scored[i][1])
	return out


## The context block injected into an agent's system prompt.
func context_for(role: String, topic: String) -> String:
	var lines: Array[String] = []
	var recalled := recall(role, topic, 5)
	if not recalled.is_empty():
		lines.append("\nYour recent memories (let them subtly inform tone and choices):")
		for m in recalled:
			lines.append("- " + str(m["text"]))
	var rel := _relationship_lines(role)
	if not rel.is_empty():
		lines.append(rel)
	return "\n".join(lines)


# ---------------------------------------------------------- relationships

func _pair(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


func nudge_affinity(a: String, b: String, delta: float) -> void:
	var key := _pair(a, b)
	affinity[key] = clampf(float(affinity.get(key, 0.5)) + delta, 0.0, 1.0)
	_save_rel()


func get_affinity(a: String, b: String) -> float:
	return float(affinity.get(_pair(a, b), 0.5))


func _relationship_lines(role: String) -> String:
	var notes: Array[String] = []
	for other in ROLES:
		if other == role:
			continue
		var v := get_affinity(role, other)
		if v >= 0.7:
			notes.append("you work especially well with the %s" % other)
		elif v <= 0.32:
			notes.append("there is some tension with the %s lately" % other)
	if notes.is_empty():
		return ""
	return "Team dynamics: " + "; ".join(notes) + "."


# ---------------------------------------------------------- persistence

func _tokens(s: String) -> Array:
	var out: Array = []
	for t in s.to_lower().split(" ", false):
		if t.length() > 3:
			out.append(t)
	return out


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(memories))


func _save_rel() -> void:
	var f := FileAccess.open(REL_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(affinity))


func _load() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary:
			for r in ROLES:
				if data.has(r) and data[r] is Array:
					memories[r] = data[r]
	if FileAccess.file_exists(REL_PATH):
		var rel: Variant = JSON.parse_string(FileAccess.get_file_as_string(REL_PATH))
		if rel is Dictionary:
			affinity = rel
