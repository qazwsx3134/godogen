// A scrolling layer of the 營地's 行軍 view: the texture repeated `tiles` times across the rect (and down it), moved
// left by `offset` (in tiles; march_view.gd advances it). `mirror` repeats a non-tiling picture back and forth so
// its seams match. Nearest filtering, for pixel art.
// The shader is godot-kit parallax_layer.
shader_type canvas_item;
#include "res://addons/proto_kit/parallax_layer.gdshaderinc"
