extends RefCounted
## Variable render delta -> bounded fixed simulation steps, without calling gameplay code.
## Extracted from skybound-blades/domain/stepper.gd and dreamling-idle/scripts/simulation_driver.gd.
## configure(seconds, max_steps, "retain"|"drop") returns Error; invalid settings leave state unchanged.
## retain keeps unprocessed seconds for later frames (idle simulation); drop discards overdue whole
## steps but keeps the fractional remainder (real-time combat). Neither reads a wall clock.
## advance(delta_seconds) returns how many times the owner should call simulation.step(step_seconds()).
## One owner, once per frame. No background catch-up unless the owner explicitly feeds that time.

var _seconds: float = 1.0 / 60.0
var _limit: int = 10
var _policy: String = "retain"
var _carry: float = 0.0
var _dropped: float = 0.0


## Reconfiguration starts a new time domain and resets accumulated/dropped time.
func configure(seconds: float, max_steps: int = 10, backlog_policy: String = "retain") -> Error:
	if not is_finite(seconds) or seconds <= 0.0 or max_steps < 1 or backlog_policy not in ["retain", "drop"]:
		return ERR_INVALID_PARAMETER
	_seconds = seconds
	_limit = max_steps
	_policy = backlog_policy
	reset()
	return OK


## Invalid/negative delta returns 0 without changing the accumulator, including existing backlog.
func advance(delta: float) -> int:
	if not is_finite(delta) or delta < 0.0 or not is_finite(_carry + delta):
		return 0
	_carry += delta
	# Compare in seconds before converting to int, avoiding overflow on huge catch-up intervals.
	var available: float = floor((_carry + _seconds * 1e-9) / _seconds)
	var count: int = int(minf(available, float(_limit)))
	_carry = maxf(0.0, _carry - count * _seconds)
	if _policy == "drop" and available > _limit:
		var remainder: float = fmod(_carry, _seconds)
		if remainder >= _seconds * (1.0 - 1e-9):
			remainder = 0.0
		_dropped += _carry - remainder
		_carry = remainder
	return count


func step_seconds() -> float:
	return _seconds


func backlog_seconds() -> float:
	return _carry


func dropped_seconds() -> float:
	return _dropped


## Render interpolation fraction; clamps to 1 when retained backlog is at least one full step.
func alpha() -> float:
	return clampf(_carry / _seconds, 0.0, 1.0)


func reset() -> void:
	_carry = 0.0
	_dropped = 0.0
