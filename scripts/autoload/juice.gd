## The "soft half" of juice doctrine (docs/CREATIVE_DIRECTION.md):
## nothing appears, disappears or changes state without a 0.2-0.4 s
## eased tween. Screenshake deliberately absent — calm is the product.
extends Node


## Scale-in with a gentle back-ease overshoot.
func pop_in(node: Node3D, dur: float = 0.3) -> void:
	if node == null:
		return
	var final := node.scale
	node.scale = final * 0.02
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", final, dur)


## Quick squash-and-recover (celebrations, landings).
func squash(node: Node3D, amount: float = 0.18, dur: float = 0.28) -> void:
	if node == null:
		return
	var base := node.scale
	var tw := node.create_tween()
	tw.tween_property(node, "scale",
		Vector3(base.x * (1.0 + amount), base.y * (1.0 - amount), base.z * (1.0 + amount)),
		dur * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, dur * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ease a node to a new position (kanban cards, props).
func slide_to(node: Node3D, target: Vector3, dur: float = 0.45) -> void:
	if node == null:
		return
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position", target, dur)


## Scale-out then free.
func pop_out(node: Node3D, dur: float = 0.25) -> void:
	if node == null:
		return
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "scale", node.scale * 0.02, dur)
	tw.tween_callback(node.queue_free)
