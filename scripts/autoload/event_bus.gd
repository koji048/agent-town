## Global signal hub. Decouples the orchestration pipeline (logic)
## from the town simulation (visuals).
extends Node

## A queue file was picked up and parsed.
signal request_received(request: Dictionary)
## A pipeline stage begins; the responsible agent should head to work.
signal stage_started(stage: String, role: String, request: Dictionary)
## A pipeline stage finished with its text result.
signal stage_completed(stage: String, role: String, request: Dictionary, result: String)
## The whole request is done and written to disk.
signal request_completed(request: Dictionary, output_dir: String)
## An agent reached its workstation.
signal agent_arrived(role: String)
## An agent wants to say something in a speech bubble.
signal agent_say(role: String, text: String)
## A line for the HUD log.
signal log_line(text: String)
## The pipeline is waiting at the approval desk (pre-publish gate).
signal approval_requested(request: Dictionary, preview: String)
## The human decided (or the auto-approve timer did).
signal approval_resolved(approved: bool)
