extends Node3D
## Root of a viewing spot scene. Holds the text the HUD shows; the scene itself holds the
## landmark, sky, sun and a Viewer instance (unique name %Viewer) on the platform.

@export var display_name := ""
@export var subtitle := ""
@export_multiline var intro := ""
@export var source_note := ""


func get_viewer() -> Node3D:
	return %Viewer


func get_sun() -> DirectionalLight3D:
	return %Sun
