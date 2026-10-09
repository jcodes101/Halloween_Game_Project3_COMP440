class_name FamiliarConstants
extends RefCounted
## Shared constants, enums, and action definitions for the Familiar Behavior System.

enum BehaviorStage {
	NORMAL = 0,
	DOUBTFUL = 1,
	CERTAIN = 2
}

const STAGE_NAMES: Dictionary = {
	BehaviorStage.NORMAL: "Normal",
	BehaviorStage.DOUBTFUL: "Doubtful",
	BehaviorStage.CERTAIN: "Certain"
}

# Standard actions performed by the Familiar
const ACTION_IDLE: String = "idle"
const ACTION_GREET: String = "greet"
const ACTION_COOKING: String = "cooking"
const ACTION_CLEANING: String = "cleaning"
const ACTION_READING: String = "reading"
const ACTION_CHECKING_PANTRY: String = "checking_pantry"
const ACTION_REPEATING_CHORE: String = "repeating_chore"
const ACTION_UNNATURAL_PAUSE: String = "unnatural_pause"
const ACTION_SLOW_TURN: String = "slow_turn"
const ACTION_STARING: String = "staring"
const ACTION_DISTURBED_IDLE: String = "disturbed_idle"
const ACTION_CONTORTION: String = "contortion"

# Certain Stage Recurring Sequence Phases
enum CertainPhase {
	EYE_CONTACT = 0,
	NECK_TWIST = 1,
	TORSO_BEND = 2,
	SHOULDER_ASYMMETRY = 3,
	ARMS_JERK = 4,
	CONTORTED_FREEZE = 5,
	SLOW_RECOVERY = 6
}

# Suspicion thresholds
const DOUBTFUL_THRESHOLD: float = 35.0
const CERTAIN_THRESHOLD: float = 75.0

# Routine station identifiers
const STATION_KITCHEN: String = "Kitchen"
const STATION_DINING: String = "Dining"
const STATION_BOOKSHELF: String = "Bookshelf"
const STATION_PANTRY: String = "Pantry"
