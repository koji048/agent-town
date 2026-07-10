## Global configuration singleton.
## Reads user_config.cfg (gitignored) or the ANTHROPIC_API_KEY env var.
## Falls back to simulate mode when no key is available so the town
## always runs.
extends Node

## Which office this town runs: "studio" (Reels crew, default) or
## "itdata" (Factory IT & Data Management floor).
var office_branch := "studio"


func set_branch(b: String) -> void:
	office_branch = b
	var f := FileAccess.open("user://office.txt", FileAccess.WRITE)
	if f:
		f.store_string(b)

var api_key: String = ""
var provider: String = "auto"          # auto | claude-code | api | simulate
var provider_resolved: String = "simulate"
var cli_path: String = ""
var model: String = "claude-sonnet-5"
var max_tokens: int = 3000
var poll_interval: float = 4.0
var simulate: bool = false
var language: String = "Thai primary, with English hooks and hashtags"
var niche: String = "Education / how-to short videos (Reels, TikTok, Shorts)"
var owner_name: String = "Boss"        # the human's name in the town
## Optional: a real production folder — finished SRTs are copied there
## EP-numbered, ready for the editor (bridges into reels workflows).
var exports_dir: String = ""


func _ready() -> void:
	if FileAccess.file_exists("user://office.txt"):
		var ob := FileAccess.get_file_as_string("user://office.txt").strip_edges()
		if ob in ["studio", "itdata"]:
			office_branch = ob
	var cfg := ConfigFile.new()
	if cfg.load("res://user_config.cfg") == OK:
		api_key = str(cfg.get_value("claude", "api_key", ""))
		model = str(cfg.get_value("claude", "model", model))
		max_tokens = int(cfg.get_value("claude", "max_tokens", max_tokens))
		provider = str(cfg.get_value("claude", "provider", provider))
		poll_interval = float(cfg.get_value("town", "poll_interval", poll_interval))
		simulate = bool(cfg.get_value("town", "simulate", false))
		language = str(cfg.get_value("content", "language", language))
		niche = str(cfg.get_value("content", "niche", niche))
		owner_name = str(cfg.get_value("town", "owner_name", owner_name))
		exports_dir = str(cfg.get_value("town", "exports_dir", exports_dir))
	if api_key.is_empty():
		api_key = OS.get_environment("ANTHROPIC_API_KEY")
	_resolve_provider()


func _resolve_provider() -> void:
	if simulate:
		provider_resolved = "simulate"
		return
	if provider == "claude-code" or provider == "auto":
		cli_path = _find_claude_cli()
		if not cli_path.is_empty():
			provider_resolved = "claude-code"
			return
		if provider == "claude-code":
			push_warning("Agent Town: provider=claude-code but CLI not found; falling back.")
	if (provider == "api" or provider == "auto" or provider == "claude-code") and not api_key.is_empty():
		provider_resolved = "api"
		return
	provider_resolved = "simulate"
	push_warning("Agent Town: no Claude Code CLI and no API key — running in simulate mode.")


func _find_claude_cli() -> String:
	var home := OS.get_environment("HOME")
	for p in [home + "/.local/bin/claude", "/opt/homebrew/bin/claude",
			"/usr/local/bin/claude", home + "/.npm-global/bin/claude"]:
		if FileAccess.file_exists(p):
			return p
	return ""


func project_dir() -> String:
	return ProjectSettings.globalize_path("res://")
