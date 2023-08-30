@tool

extends "../scene_baker.gd"

const OctahedralUtils = preload("../utils/octahedral_utils.gd")

# Baking params
var atlas_coverage := 1.0
var frames_xy := 12
var is_full_sphere := false
var atlas_resolution := 2048

# Original scene params
var scene_to_bake: Node3D
var imported_scene_scale: Vector3

var camera_distance: float
var camera_distance_scaled: float


@onready var baking_camera: Camera3D = $Camera3D


func get_pivot_translation() -> Vector3:
	return scene_to_bake.position * (-1.0) * frames_xy


func get_scene_to_bake_aabb(node := scene_to_bake) -> AABB:
	#var aabb := AABB(Vector3.ONE * 65536.0, -Vector3.ONE * 65536.0 * 2.0) # what is this??
	var aabb := AABB()
	if node is GeometryInstance3D and not node is CSGShape3D:
		aabb = aabb.merge(node.global_transform * node.mesh.get_aabb().abs()) # This assumes it is a mesh instance. TODO: Generalize
	for child in node.get_children():
		aabb = aabb.merge(get_scene_to_bake_aabb(child))
	return aabb.abs()


func update_scene_to_bake_transform() -> void:
	scene_to_bake.scale = imported_scene_scale * atlas_coverage
	# scale down for all frames
	scene_to_bake.scale *= 1.0/float(frames_xy)
	var aabb: AABB = get_scene_to_bake_aabb()
	scene_to_bake.position -= aabb.position + aabb.size / 2.0


func setup_camera_position(camera: Marker3D, position: Vector3) -> void:
	var z: Vector3 = position.normalized()
	if z.abs() == Vector3(0, 1, 0):
		camera.look_at_from_position(position, Vector3.ZERO, Vector3.BACK)
		return
	camera.look_at_from_position(position, Vector3.ZERO, Vector3.UP)


func create_frame_xy_scene(frame: Vector2) -> void:
	var cam_pos = Marker3D.new()
	var container := Node3D.new()
	var scale := camera_distance / float(frames_xy)
	var uv_coord: Vector2 = frame / float(frames_xy - 1)
	var normal := OctahedralUtils.grid_to_vector(uv_coord, is_full_sphere)

	var d_baked_scene = scene_to_bake.duplicate()
	d_baked_scene.rotation = Vector3()
	container.add_child(d_baked_scene)
	container.add_child(cam_pos)
	$BakedContainer.add_child(container)
	container.show()
	d_baked_scene.show()
	cam_pos.show()
	setup_camera_position(cam_pos, normal * camera_distance_scaled)
	d_baked_scene.transform = cam_pos.transform.affine_inverse() * d_baked_scene.transform
	d_baked_scene.global_transform.origin.z = 0
	container.transform.origin = Vector3(0,0,0)
	container.position.x = (float(frames_xy)/2.0 - float(frame.x) -0.5 )* (-scale)
	container.position.y = (float(frames_xy)/2.0 - float(frame.y) -0.5 )* scale
	container.remove_child(cam_pos)


func prepare_scene(node: Node3D) -> void:
	scene_to_bake = node.duplicate()
	# we need to add this scene to a tree to recalculate aabb
	$BakedContainer.add_child(scene_to_bake)
	scene_to_bake.show()

	scene_to_bake.position = Vector3()
	scene_to_bake.rotation = Vector3()
	var aabb: AABB = get_scene_to_bake_aabb()
	imported_scene_scale = scene_to_bake.scale
	update_scene_to_bake_transform()

	camera_distance = aabb.size.length()
	camera_distance_scaled = camera_distance / float(frames_xy)
	baking_camera.size = camera_distance
	baking_camera.far = camera_distance_scaled * 2.0
	baking_camera.global_transform.origin.z = camera_distance_scaled
	$BakedContainer.remove_child(scene_to_bake)


func prepare_viewport(vp: SubViewport) -> void:
	vp.size = Vector2(atlas_resolution, atlas_resolution)


func set_scene_to_bake(node: Node3D) -> void:
	var viewport = get_viewport()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	prepare_viewport(viewport)
	if scene_to_bake:
		scene_to_bake.queue_free()
	prepare_scene(node)
	for x in frames_xy:
		for y in frames_xy:
			create_frame_xy_scene(Vector2(x,y))
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var atlas_image = viewport.get_texture().get_image()
	atlas_image.flip_y()
	atlas_image.convert(Image.FORMAT_RGBAH)
	set_atlas_image(atlas_image)
	emit_signal("atlas_ready")


func cleanup() -> void:
	var viewport = get_viewport()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for n in $BakedContainer.get_children():
		$BakedContainer.remove_child(n)


func get_camera_3d() -> Camera3D:
	return baking_camera
