class_name ItemDefinitions
extends RefCounted
## One definition per unique physical item. Story text is editable here or can
## be overridden on an InspectableClue. Collection alone never confirms evidence.

const BASEMENT_KEY: String = "basement_key"
const CROWBAR: String = "crowbar"
const MOM_MEMORABILIA_1: String = "mom_memorabilia_1"
const MOM_MEMORABILIA_2: String = "mom_memorabilia_2"
const MIMIC_MEMORABILIA_1: String = "mimic_memorabilia_1"
const MIMIC_MEMORABILIA_2: String = "mimic_memorabilia_2"

static func get_definition(item_id: String) -> Dictionary:
	var definitions: Dictionary = {
		BASEMENT_KEY: _item(BASEMENT_KEY, "Basement Key", "key", "basement"),
		CROWBAR: _item(CROWBAR, "Crowbar", "tool"),
		MOM_MEMORABILIA_1: _memory(MOM_MEMORABILIA_1, "Mom's Recipe Card", "Mom always tapped the spoon twice before tasting the soup. Her recipe card calls it our little signal. Tonight, the person at the stove watched me and tapped three times."),
		MOM_MEMORABILIA_2: _memory(MOM_MEMORABILIA_2, "Mom's Unfinished Letter", "The last line is pressed deep into the paper: 'If I come home without remembering our signal, keep the basement locked.' Beneath it, another hand has carefully practiced Mom's signature."),
		MIMIC_MEMORABILIA_1: _memory(MIMIC_MEMORABILIA_1, "Hidden Rehearsal Notes", "A folded page lists Mom's greetings, pauses, and laughs. Beside 'my child' someone wrote: 'Wait for them to answer before choosing the right name.'"),
		MIMIC_MEMORABILIA_2: _memory(MIMIC_MEMORABILIA_2, "Impossible Family Photograph", "In the photograph, Mom's face smiles from the hallway mirror while her body faces away. The reflection's fingers bend at too many joints. On the back: 'The shape is easy. The memories take longer.'")
	}
	return definitions.get(item_id, {}).duplicate(true)

static func create_room_key(room_id: String, display_name: String = "") -> Dictionary:
	if room_id.strip_edges().is_empty():
		return {}
	var label: String = display_name if not display_name.is_empty() else room_id + " Key"
	return _item("room_key:" + room_id, label, "key", room_id)

static func get_memorabilia_ids() -> Array[String]:
	return [MOM_MEMORABILIA_1, MOM_MEMORABILIA_2, MIMIC_MEMORABILIA_1, MIMIC_MEMORABILIA_2]

static func _item(id: String, label: String, kind: String, room: String = "") -> Dictionary:
	return {"id": id, "display_name": label, "kind": kind, "room_id": room, "requires_inspection": false, "clue_id": "", "story_text": ""}

static func _memory(id: String, label: String, story: String) -> Dictionary:
	return {"id": id, "display_name": label, "kind": "memorabilia", "room_id": "", "requires_inspection": true, "clue_id": id, "story_text": story}
