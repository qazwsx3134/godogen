extends RefCounted
class_name StepProvider

## Interface for a step-count source.
##
## This is deliberately a game-facing interface, not an iOS/Android API.  A
## native provider can subclass it when a platform plugin is available.  The
## base implementation is a safe release fallback: it never fabricates a
## count and reports that the source is unavailable.

const SOURCE_NATIVE: String = "native"
const STATUS_UNAVAILABLE: String = "unavailable"

func capabilities() -> Dictionary:
	return {
		"source": SOURCE_NATIVE,
		"available": false,
		"historical": false,
		"background": false,
		"debug": false,
	}

func permission() -> String:
	return "unknown"

func query(_state: Dictionary, from_utc: int, to_utc: int) -> Dictionary:
	var query_from: int = from_utc
	var query_to: int = max(to_utc, query_from)
	return {
		"source": SOURCE_NATIVE,
		"status": STATUS_UNAVAILABLE,
		"coverage": {
			"from_utc": query_from,
			"to_utc": query_to,
			"complete": false,
			"known": false,
		},
		"buckets": [],
		"today_steps": null,
		"message": "原生步數來源尚未串接，無法取得步數。",
	}
