extends RefCounted
## QA export has its own progress file. Editor command-line tools opt in by using QA arguments.
## Production exports never accept duration/autoplay/seed/hero overrides.
const SAVE_PATH := "user://survivor_meta_qa.json"

static func enabled() -> bool:
	if OS.has_feature("survivor_qa"):
		return true
	if OS.has_feature("editor") and not OS.has_feature("web"):
		for argument: String in OS.get_cmdline_user_args():
			if argument == "--autoplay" or argument.begins_with("--duration=") or argument.begins_with("--seed=") or argument.begins_with("--hero="):
				return true
	return false
