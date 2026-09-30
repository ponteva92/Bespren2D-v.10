class_name BesprenBootstrap
extends Node2D
## Composition root for the technical foundation. Gameplay systems are absent by design.

signal foundation_ready(local_player_count: int)

@onready var coop_session: CoopSession = %CoopSession

var local_roster: LocalCoopRoster


func _ready() -> void:
	local_roster = LocalCoopRoster.create_default()
	if local_roster.size() != LocalCoopRoster.MAX_LOCAL_PLAYERS:
		push_error("Bespren local co-op roster failed to initialize")
		return
	foundation_ready.emit(local_roster.size())

