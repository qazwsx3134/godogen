extends RefCounted
## Ephemeral, segment-local history. Saves never serialize it and barriers cannot be crossed.
const LIMIT: int = 64
var _states: Array[Dictionary] = []
func remember(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	_states.append(payload.duplicate(true))
	if _states.size() > LIMIT:
		_states.pop_front()
func available() -> bool:
	return not _states.is_empty()
func take() -> Dictionary:
	return _states.pop_back() if available() else {}
func clear() -> void:
	_states.clear()
