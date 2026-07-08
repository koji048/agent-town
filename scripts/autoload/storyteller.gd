## The RimWorld lesson (docs/CREATIVE_DIRECTION.md, pillar 5): agents
## don't schedule drama — a storyteller does. Tension accrues from real
## pipeline outcomes; when it crests, one event fires (scaled to the
## shipping streak), then an enforced calm window lets the moment land.
## Events are written into the agents' MEMORIES, so drama genuinely
## changes future behavior instead of being wallpaper.
extends Node

const CALM_SECONDS := 300.0
const TRENDS := [
	"POV hooks are outperforming tutorials this week",
	"green-screen replies are trending on Thai TikTok",
	"3-second cold opens are beating intros everywhere",
	"carousel-to-reel crossposts are getting boosted",
	"day-in-the-life edits are having a moment again",
]

var tension := 0.0
var streak := 0
var espresso_down := false
var _last_event_at := 0.0


func _ready() -> void:
	EventBus.stage_completed.connect(func(_s, _r, _q, out: String) -> void:
		tension += 0.14 if out.begins_with("(stage") else 0.07)
	EventBus.request_completed.connect(func(_q, _o) -> void:
		streak += 1
		tension += 0.12)
	var t := Timer.new()
	t.wait_time = 45.0
	t.timeout.connect(_tick)
	add_child(t)
	t.start()


func _tick() -> void:
	var now := Time.get_unix_time_from_system()
	if now - _last_event_at < CALM_SECONDS:
		return
	# the better the office is doing, the spicier the odds (RimWorld
	# wealth-scaling): base chance needs tension, streak sweetens it
	var chance := clampf(tension - 0.5, 0.0, 0.4) + minf(streak * 0.03, 0.15)
	if randf() > chance:
		return
	_last_event_at = now
	tension = 0.0
	match randi() % 3:
		0:
			_trend_alert()
		1:
			_espresso_outage()
		2:
			_deadline_pressure()


func _trend_alert() -> void:
	var trend: String = TRENDS.pick_random()
	EventBus.log_line.emit("📈 TREND ALERT: %s" % trend)
	EventBus.agent_say.emit("director", I18n.f("st_trend_say", [trend]))
	Memory.remember_all(I18n.f("mem_trend", [trend]), 6.0)
	Chronicle.record("trend", "Trend alert swept the office: %s" % trend)


func _espresso_outage() -> void:
	if espresso_down:
		return
	espresso_down = true
	EventBus.log_line.emit("☕ The espresso machine is DOWN.")
	EventBus.agent_say.emit("editor", I18n.t("st_espresso_down"))
	Memory.remember_all(I18n.t("mem_espresso_down"), 5.0)
	Chronicle.record("outage", "The Great Espresso Outage")
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		espresso_down = false
		EventBus.log_line.emit("☕ Espresso machine repaired. Order restored.")
		EventBus.agent_say.emit("publisher", I18n.t("st_espresso_up"))
		Memory.remember_all(I18n.t("mem_espresso_up"), 4.0))


func _deadline_pressure() -> void:
	EventBus.log_line.emit("⏰ A rush client wants the next reel FAST.")
	EventBus.agent_say.emit("director", I18n.t("st_rush_say"))
	Memory.remember_all(I18n.t("mem_rush"), 6.0)
	Chronicle.record("rush", "A rush deadline rattled the crew")
