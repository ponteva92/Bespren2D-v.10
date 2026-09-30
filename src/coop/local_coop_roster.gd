class_name LocalCoopRoster
extends RefCounted
## Owns local seats only. It deliberately contains no movement or combat logic.

signal slot_joined(slot: PlayerSlotDefinition)
signal slot_removed(slot_id: int)

const MAX_LOCAL_PLAYERS: int = 2

var _slots: Array[PlayerSlotDefinition] = []


static func create_default() -> LocalCoopRoster:
	var roster := LocalCoopRoster.new()
	var heikki := PlayerSlotDefinition.new(
		1,
		&"Heikki",
		PlayerSlotDefinition.ControlScheme.TOUCH_AND_KEYBOARD,
		InputEvent.DEVICE_ID_KEYBOARD,
		Color("ffd45a")
	)
	var shane := PlayerSlotDefinition.new(
		2,
		&"Shane",
		PlayerSlotDefinition.ControlScheme.JOYPAD,
		1,
		Color("31e6e6")
	)
	roster.register_slot(heikki)
	roster.register_slot(shane)
	return roster


func register_slot(slot: PlayerSlotDefinition) -> Error:
	if slot == null or not slot.is_valid():
		return ERR_INVALID_PARAMETER
	if _slots.size() >= MAX_LOCAL_PLAYERS or get_slot(slot.slot_id) != null:
		return ERR_ALREADY_EXISTS
	if slot.control_scheme == PlayerSlotDefinition.ControlScheme.JOYPAD:
		for existing: PlayerSlotDefinition in _slots:
			if (
				existing.control_scheme == PlayerSlotDefinition.ControlScheme.JOYPAD
				and existing.device_id == slot.device_id
			):
				return ERR_ALREADY_IN_USE
	_slots.append(slot)
	_slots.sort_custom(func(a: PlayerSlotDefinition, b: PlayerSlotDefinition) -> bool: return a.slot_id < b.slot_id)
	slot_joined.emit(slot)
	return OK


func remove_slot(slot_id: int) -> Error:
	var slot := get_slot(slot_id)
	if slot == null:
		return ERR_DOES_NOT_EXIST
	_slots.erase(slot)
	slot_removed.emit(slot_id)
	return OK


func get_slot(slot_id: int) -> PlayerSlotDefinition:
	for slot: PlayerSlotDefinition in _slots:
		if slot.slot_id == slot_id:
			return slot
	return null


func get_slots() -> Array[PlayerSlotDefinition]:
	var result: Array[PlayerSlotDefinition] = []
	result.assign(_slots)
	return result


func find_slot_for_event(event: InputEvent) -> PlayerSlotDefinition:
	for slot: PlayerSlotDefinition in _slots:
		if slot.accepts_event(event):
			return slot
	return null


func size() -> int:
	return _slots.size()

