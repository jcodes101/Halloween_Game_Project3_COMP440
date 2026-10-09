class_name MonsterObservation
extends RefCounted
## Read-only input snapshot supplied by the owning systems through an adapter.
## These enum representations are local prototype contracts, not team-wide state.
enum DoorState { CLOSED, OPEN }
enum EscapePhase { EXPLORING, BASEMENT_READY, ESCAPED }

var suspicion_level: float = 0.0
var player_location := Vector3.ZERO
var is_hidden := false
var player_is_still := true
var hiding_check_position := Vector3.ZERO
var door_state: DoorState = DoorState.CLOSED
var escape_progress: EscapePhase = EscapePhase.EXPLORING

