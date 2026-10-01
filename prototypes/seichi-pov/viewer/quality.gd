extends RefCounted
## Static device tiers (after AOT's Quality.js): render scale, MSAA and sun shadows.
## Override with `-- --quality=low|mid|high` on the command line.

const TIERS := {
	"high": {"scale": 1.0, "msaa": Viewport.MSAA_4X, "shadows": true, "shadow_distance": 500.0},
	"mid": {"scale": 0.85, "msaa": Viewport.MSAA_2X, "shadows": true, "shadow_distance": 350.0},
	"low": {"scale": 0.7, "msaa": Viewport.MSAA_DISABLED, "shadows": false, "shadow_distance": 0.0},
}


static func pick() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			return arg.trim_prefix("--quality=")
	if not OS.has_feature("mobile"):
		return "high"
	var mem: Dictionary = OS.get_memory_info()
	var gib := float(mem.get("physical", 0)) / 1073741824.0
	return "low" if gib > 0.0 and gib < 3.5 else "mid"


static func apply(viewport: Viewport, sun: DirectionalLight3D, tier: String) -> void:
	var t: Dictionary = TIERS.get(tier, TIERS.mid)
	viewport.scaling_3d_scale = t.scale
	viewport.msaa_3d = t.msaa
	sun.shadow_enabled = t.shadows
	if t.shadows:
		sun.directional_shadow_max_distance = t.shadow_distance
	print("quality tier: ", tier)
