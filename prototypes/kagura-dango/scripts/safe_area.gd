class_name SafeArea
extends Control
## A full-screen Control that pulls its edges in by the device's safe area (a phone's notch, rounded corners, home
## indicator), in canvas units, so whatever is laid out inside it stays clear of them. Only phones and the web build
## have one: a desktop's "safe area" is the screen minus the dock and menu bar, which a window does not need to avoid.
## The web build reads CSS env(safe-area-inset-*), which is 0 unless the page draws under the notch (fullscreen /
## viewport-fit=cover), so a browser that already keeps the page clear of it changes nothing.

## Tests and screenshots: `-- --safe-inset=L,T,R,B` (canvas units) pretends there is a notch. x < 0 = not set.
static var override := Vector4(-1, -1, -1, -1)


func _ready() -> void:
	get_viewport().size_changed.connect(fit)
	fit()


func fit() -> void:
	var i := insets(get_viewport())
	offset_left = i.x
	offset_top = i.y
	offset_right = -i.z
	offset_bottom = -i.w


## Left, top, right, bottom insets in canvas units.
static func insets(viewport: Viewport) -> Vector4:
	if override.x < 0.0:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--safe-inset="):
				var v := arg.trim_prefix("--safe-inset=").split_floats(",")
				if v.size() == 4:
					override = Vector4(v[0], v[1], v[2], v[3])
	if override.x >= 0.0:
		return override
	var canvas := viewport.get_visible_rect().size
	if OS.has_feature("web"):
		var css := str(JavaScriptBridge.eval("""(() => {
			const d = document.createElement('div');
			d.style.cssText = 'position:fixed;left:0;top:0;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
			document.body.appendChild(d);
			const s = getComputedStyle(d);
			const r = [s.paddingLeft, s.paddingTop, s.paddingRight, s.paddingBottom, window.innerWidth].map(parseFloat).join(',');
			d.remove();
			return r;
		})()""")).split_floats(",")
		if css.size() == 5 and css[4] > 0.0:
			var k := canvas.x / css[4]
			return Vector4(css[0], css[1], css[2], css[3]) * k
	elif OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var win := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
		if win.size.x > 0:
			var k := canvas.x / win.size.x
			return Vector4(maxi(0, safe.position.x - win.position.x), maxi(0, safe.position.y - win.position.y),
				maxi(0, win.end.x - safe.end.x), maxi(0, win.end.y - safe.end.y)) * k
	return Vector4.ZERO
