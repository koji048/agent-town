## Global configuration singleton.
## Reads user_config.cfg (gitignored) or the ANTHROPIC_API_KEY env var.
## Falls back to simulate mode when no key is available so the town
## always runs.
extends Node

var api_key: String = ""
var model: String = "claude-sonnet-5"
var max_tokens: int = 3000
var poll_interval: float = 4.0
var simulate: bool = false
var language: String = "Thai primary, with English hooks and hashtags"
var niche: String = "Education / how-to short videos (Reels, TikTok, Shorts)"


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://user_config.cfg") == OK:
		api_key = str(cfg.get_value("claude", "api_key", ""))
		model = str(cfg.get_value("claude", "model", model))
		max_tokens = int(cfg.get_value("claude", "max_tokens", max_tokens))
		poll_interval = float(cfg.get_value("town", "poll_interval", poll_interval))
		simulate = bool(cfg.get_value("town", "simulate", false))
		language = str(cfg.get_value("content", "language", language))
		niche = str(cfg.get_value("content", "niche", niche))
	if api_key.is_empty():
		api_key = OS.get_environment("ANTHROPIC_API_KEY")
	if api_key.is_empty() and not simulate:
		simulate = true
		push_warning("Agent Town: no API key found (user_config.cfg or ANTHROPIC_API_KEY). Running in simulate mode.")


func project_dir() -> String:
	return ProjectSettings.globalize_path("res://")
