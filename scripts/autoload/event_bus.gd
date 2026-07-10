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
## An agent asks the owner ONE clarifying question (mixed initiative).
signal agent_question(role: String, question: String)
## The owner's typed guidance for the asking agent ("" = no answer).
signal guidance_given(text: String)
## The Director calls a kickoff huddle before a new job starts.
signal meeting_called(request: Dictionary)
## Anything anyone actually said out loud (for the office chat feed).
signal chat_line(speaker: String, text: String)
## A stage handoff: FROM passes the work to TO (delegation-flow visuals).
signal handoff(from_role: String, to_role: String, stage: String, request: Dictionary)
## The owner cancelled a running project from the board.
signal provider_limited(reason: String, until_unix: int)
signal request_cancelled(request: Dictionary)
## A clip is ready for the Caption Review Studio (pre-burn gate).
signal clip_review_requested(request: Dictionary, srt_path: String, preview_dir: String)
## The studio's verdict: "default" or "custom" (with a style dict).
signal clip_review_resolved(action: String, style: Dictionary)
