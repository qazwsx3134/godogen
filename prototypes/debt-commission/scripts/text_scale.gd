extends RefCounted
## Readable text on phones. The scenes' font sizes are design pixels picked for a desktop or tablet window;
## on a phone one CSS px holds about 2.8 design px, so a 32 px label reads as 11–12 CSS px. main sets a
## multiplier from the screen's density (1.0 on desktop, up to MAX on a phone) and every Label, Button and
## RichTextLabel below LARGE takes its authored size times it. The authored size is remembered on the node,
## so a multiplier of 1 puts the scene's own value back. Display text (manga bursts, titles) is LARGE already
## and left alone; a node with metadata `fixed_font_size` is skipped too.

const LARGE: int = 44
const MAX: float = 1.25
const BASE: StringName = &"_authored_font_size"


## 1.0 up to about 1.8 design px per CSS px (desktop, tablet), MAX from about 2.6 (phones).
static func multiplier(design_px_per_css_px: float) -> float:
	return 1.0 + (MAX - 1.0) * clampf((design_px_per_css_px - 1.8) / 0.8, 0.0, 1.0)


static func apply_tree(root: Node, factor: float) -> void:
	apply(root, factor)
	for node: Node in root.find_children("*", "Control", true, false):
		apply(node, factor)


static func apply(node: Node, factor: float) -> void:
	if not (node is Label or node is Button or node is RichTextLabel) or node.has_meta(&"fixed_font_size"):
		return
	var control: Control = node as Control
	var kind: StringName = &"normal_font_size" if control is RichTextLabel else &"font_size"
	if not control.has_meta(BASE):
		if is_equal_approx(factor, 1.0):
			return  # still as authored
		control.set_meta(BASE, control.get_theme_font_size(kind))
	var base: int = int(control.get_meta(BASE))
	if base >= LARGE:
		return
	var size: int = mini(roundi(base * factor), LARGE)
	control.add_theme_font_size_override(kind, size)
	if control is RichTextLabel:
		for other: StringName in [&"bold_font_size", &"italics_font_size", &"bold_italics_font_size", &"mono_font_size"]:
			control.add_theme_font_size_override(other, size)
