@tool
extends Node3D
## 大量草：一個 MultiMeshInstance3D 一個 chunk，每個 chunk 一次 draw call，不是一根草一個 node。
## 在編輯器改 export 後按 Rebuild（勾一下）重新撒草；產生的 chunk 存進 scene。
## 每個 chunk 設 visibility_range_end（遠了整塊不畫）、不投影，並用 MultiMesh custom data 給每個 chunk 一點顏色差。

@export var material: ShaderMaterial
@export var area := Vector2(80, 80)
@export var total := 22000
@export var chunks_per_side := 17      ## 17×17 = 289 個 chunk
@export var visibility_end := 65.0
@export var blade_height := Vector2(0.35, 0.7)
@export var tint_jitter := 0.12
@export var seed := 1
@export var rebuild := false:
	set(v):
		if v and is_inside_tree():
			build()


func build() -> void:
	for c in get_children():
		c.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mesh := blade_mesh()
	var n := chunks_per_side
	var cell := area / n
	var per := ceili(float(total) / (n * n))
	for cx in n:
		for cz in n:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = mesh
			mm.instance_count = per
			var origin := Vector3(-area.x / 2 + (cx + 0.5) * cell.x, 0, -area.y / 2 + (cz + 0.5) * cell.y)
			var j := rng.randf_range(-tint_jitter, tint_jitter)
			var tint := Color(1.0 + j, 1.0 + j * 0.5, 1.0 - j * 0.5, 1.0)
			for i in per:
				mm.set_instance_custom_data(i, tint)
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(blade_height.x, blade_height.y))
				mm.set_instance_transform(i, Transform3D(b, Vector3(rng.randf_range(-0.5, 0.5) * cell.x, 0, rng.randf_range(-0.5, 0.5) * cell.y)))
			var mi := MultiMeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx, cz]
			mi.multimesh = mm
			mi.position = origin
			mi.material_override = material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = visibility_end
			mi.visibility_range_end_margin = 5.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mi)
			mi.owner = owner if owner != null else self


## 一片草：3 段漸窄的面，頂點色 R = 高度比例（根 0、尖 1），shader 靠它決定顏色與彎曲。
static func blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 3
	var w := 0.05
	for s in seg:
		var y0 := float(s) / seg
		var y1 := float(s + 1) / seg
		var w0 := w * (1.0 - y0)
		var w1 := w * (1.0 - y1)
		var q := [Vector3(-w0, y0, 0), Vector3(w0, y0, 0), Vector3(w1, y1, 0), Vector3(-w1, y1, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(q[idx].y, 0, 0))
			st.set_normal(Vector3(0, 0.6, 1).normalized())
			st.add_vertex(q[idx])
	return st.commit()
