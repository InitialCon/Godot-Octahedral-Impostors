@tool
# based on: https://github.com/godot-extended-libraries/godot-lod/blob/master/addons/lod/lod_spatial.gd
@icon ("../icons/icon_octaimpostor.svg")
extends Node3D
class_name OctaImpostor

const FileUtils = preload("baking/utils/file_utils.gd")
const ProfileResource = preload("profile_resource.gd")
const ProfilesDir = "res://addons/octahedral_impostors/profiles/"

@export var enable_lod := true
@export_range(0.0, 1000.0, 0.1) var lod_distance: float = 50 # (float, 0.0, 1000.0, 0.1)
@export var profile: Resource = null
@export_enum("1024", "2048", "4096") var atlas_resolution: int = 1 # (int, "1024", "2048", "4096")
@export var frames_xy: int = 12
@export var is_full_sphere: bool = false
@export var optimize_atlas_size: bool = false
@export var create_shadow_mesh: bool = false

var refresh_rate := 0.25
var counter := 0.0
var editor_camera :Camera3D = null

#TODO: dynamically load baking profiles as optionbutton

func read_baking_profiles(profile_button: OptionButton) -> Array:
	profile_button.clear()
	var profiles: Array = FileUtils.get_resources_in_dir(ProfilesDir)
	var profile_id = 0
	for prof in profiles:
		if prof is ProfileResource:
			profile_button.add_item(prof.name, profile_id)
			profile_button.set_item_metadata(profile_id, prof)
			profile_id += 1
	return profiles


func _physics_process(delta: float) -> void:
	if not enable_lod:
		return

	# We need a camera to do the rest.
	var camera := get_viewport().get_camera_3d()
	if Engine.is_editor_hint() && editor_camera != null:
		camera = editor_camera
	if camera == null:
		return

	if counter <= refresh_rate:
		counter += delta
		return
	counter = 0.0

	var distance := camera.global_transform.origin.distance_to(global_transform.origin)
	# The LOD level to choose (lower is more detailed).
	var lod: int
	if distance < lod_distance:
		lod = 0
	else:
		lod = 1

	for node in get_children():
		if node.has_method("set_visible"):
			if "-impostor" in node.name:
				node.visible = lod == 1
			else:
				node.visible = lod == 0
