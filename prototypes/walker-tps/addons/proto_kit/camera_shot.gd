extends Resource
## One short cinematic move of a fixed gameplay camera (shot_camera.gd): ease from the gameplay framing toward a
## focus point, hold, ease back. Save each move as a .tres so it is tuned in the inspector. Projects that want a typed
## name subclass it: `class_name CameraShot` + `extends "res://addons/proto_kit/camera_shot.gd"`.

## Metres the camera dollies toward the focus point.
@export var push_m: float = 2.0
## Orbit around the focus before the dolly: yaw turns around world up (+ = camera swings right), pitch raises (+) or
## lowers (-) the camera. Keep yaw small: the field sprites are drawn facing one way and read as cards from the side.
@export_range(-20.0, 20.0) var yaw_deg: float = 0.0
@export_range(-20.0, 20.0) var pitch_deg: float = 0.0
## Added to the camera's field of view (degrees; - = tighter).
@export var fov_delta: float = 0.0
@export var ease_in: float = 0.3
## Seconds held at the peak; < 0 holds until the director is released or reset (the win shot).
@export var hold: float = 0.5
@export var ease_out: float = 0.5
## Higher interrupts lower; equal replaces.
@export var priority: int = 1
## Game-time freeze at the start of the shot (hit stop), seconds.
@export var hit_stop: float = 0.0
## Screen shake added at the start, 0..1.
@export var trauma: float = 0.0
