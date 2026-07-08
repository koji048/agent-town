## The owner's rule, verbatim: agents never wait for EACH OTHER — a
## person only waits when two of THEIR OWN tasks overlap. One async
## lock per role (plus one for the single approval desk).
extends Node

var _busy: Dictionary = {}


func acquire(key: String) -> void:
	while _busy.get(key, false):
		await get_tree().create_timer(0.25).timeout
	_busy[key] = true


func release(key: String) -> void:
	_busy[key] = false
