extends SceneTree
var shaders: Array[Shader] = []
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_scan(args[0])
	print("SHADERS CHECKED: ", shaders.size())
	quit()
func _scan(path: String) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".gdshader"):
			print("CHECK ", path.path_join(file))
			var shader := Shader.new()
			shader.code = FileAccess.get_file_as_string(path.path_join(file))
			shader.get_shader_uniform_list()
			shaders.append(shader)
	for folder: String in DirAccess.get_directories_at(path):
		_scan(path.path_join(folder))
