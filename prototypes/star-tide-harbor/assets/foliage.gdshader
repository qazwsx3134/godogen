shader_type canvas_item;
uniform float sway = 2.0;
uniform float phase = 0.0;
void vertex() {
	float crown = (1.0 - UV.y) * (1.0 - UV.y);
	VERTEX.x += floor(sin(TIME * 1.05 + phase) * sway * crown + 0.5);
}
