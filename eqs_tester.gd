class_name EQS extends Node3D

var eqs_marker = preload("res://Management/EQS/marker.tscn")
var marker_array = []

@export_category("GRID")
@export var point_count : int = 9
@export var point_distance : float = 2.0
@export var skip_origin : bool
@export var grid_origin : Vector3
@export var debug_shapes : bool = false
#helpful for stuff like cover
@export var use_navmesh_coordinate : bool = false
var debug_array = []

@export_category("RAYCASTING")
#region
@export var raycast_context : Vector3
@export var use_raycast : bool = false
@export var raycast_size : float = .25
@export var use_shapecast : bool = false
@export var shapecast_shape : Shape3D
#if checked, allow nodes where the raycast collides
#with the target layers
@export var raycast_invert_result : bool = false
#cast from the context outwards rather than inwards
@export var from_context : bool = true
@export_flags_3d_physics var RaycastLayers

@onready var test_cast = $RayCast3D
@onready var test_shape_cast = $ShapeCast3D
#endregion

@export_category("DISTANCE")
#region
enum DISTANCE_PARAMETER {MIN, MAX, RANGE, RANGE_INVERTED}
@export var distance_context : Vector3
@export var consider_distance : bool
@export var distance_filtering : DISTANCE_PARAMETER
@export var min_dist : float = 0.0
@export var max_dist : float = 20.0
#endregion

@export_category("PATHFINDING")
@onready var nav_parent = $Node3D
@onready var pathfinder = $Node3D/NavigationAgent3D
@export var pathfinder_context : Vector3
@export var check_pathfinder : bool


func _ready():
	top_level = true
	if shapecast_shape != null:
		test_shape_cast.shape = shapecast_shape
	if RaycastLayers != null:
		test_cast.collision_mask = RaycastLayers
		test_shape_cast.collision_mask = RaycastLayers

func _physics_process(_delta: float) -> void:
	pass

func request_query():
	# Reset rotation here; top_level alone doesn't keep the grid axis-aligned
	global_rotation = Vector3.ZERO
	
	create_eqs_grid(point_count, point_distance)
	perform_tests()
	#return array with values
	return marker_array
	
func create_eqs_grid(_width,_distance):
	if !debug_array.is_empty():
		for shape in debug_array:
			shape.queue_free()
		debug_array.clear()
	
	if grid_origin != null:
		global_position = grid_origin
	
	if _width % 2 == 0:
		print("CREATE GRID USES EVEN NUMBER, GRID WILL BE OFFSET")
	
	#clear last grid
	if !marker_array.is_empty():
		marker_array.clear()
	
	var marker_position = global_position
	marker_position.x -= (_width/2) * _distance
	marker_position.z -= (_width/2) * _distance
	
	for mark in range(_width):
		for marker in range(_width):
			#skip the position we are actually on, can be optional argument
			if skip_origin:
				if !marker_position.is_equal_approx(global_position):
					if use_navmesh_coordinate:
						var TBA = NavigationServer3D.map_get_closest_point(get_world_3d().get_navigation_map(),marker_position)
						marker_array.append(Vector3(TBA.x, grid_origin.y, TBA.z))
					else:
						marker_array.append(marker_position)
			else:
				if use_navmesh_coordinate:
					var TBA = NavigationServer3D.map_get_closest_point(get_world_3d().get_navigation_map(),marker_position)
					marker_array.append(Vector3(TBA.x, grid_origin.y, TBA.z))
				else:
					marker_array.append(marker_position)
					
					
			marker_position.x += _distance
			
		marker_position.z += _distance
		marker_position.x = global_position.x - (_width/2) * _distance
	
# TODO: refactor to rely less on scene nodes

func perform_tests():
	#so we don't test already disallowed nodes to save performance
	var to_remove = []
	
	#start with the lowest cost tests first
	
	####################
	## DISTANCE TESTS ##
	####################
	
	if consider_distance:
		
		#we may want to check somewhere else besides the grid origin e.g. near an enemy
		var test_point = global_position
		if distance_context != null:
			test_point = distance_context
		
		for marker in marker_array:
			match distance_filtering:
				DISTANCE_PARAMETER.MIN:
					if marker.distance_to(test_point) < min_dist:
						to_remove.append(marker)
				DISTANCE_PARAMETER.MAX:
					if marker.distance_to(test_point) > max_dist:
						to_remove.append(marker)
				DISTANCE_PARAMETER.RANGE:
					if marker.distance_to(test_point) > max_dist or marker.distance_to(test_point) < min_dist:
						to_remove.append(marker)
				#doesn't consider points in range
				DISTANCE_PARAMETER.RANGE_INVERTED:
					if marker.distance_to(test_point) < max_dist and marker.distance_to(test_point) > min_dist:
						to_remove.append(marker)
	
	remove_elements(to_remove)

	#############################
	## SHAPE AND RAYCAST TESTS ##
	#############################
	
	if use_shapecast:
		
		var test_point = global_position
		if raycast_context != null:
			test_point = raycast_context
		
		for marker in marker_array:
			if !from_context:
				test_shape_cast.global_position = marker
				test_shape_cast.target_position = test_point - test_shape_cast.global_position
			else:
				test_shape_cast.global_position = test_point
				test_shape_cast.target_position = marker - test_shape_cast.global_position
			
			test_shape_cast.force_update_transform()
			test_shape_cast.force_shapecast_update()
			
			if !raycast_invert_result:
				if test_shape_cast.is_colliding():
					to_remove.append(marker)
			else:
				if !test_shape_cast.is_colliding():
					to_remove.append(marker)
					
	elif use_raycast:
		
		var test_point = global_position
		if raycast_context != null:
			test_point = raycast_context
		
		for marker in marker_array:
			
			# Cast one ray, or three (center plus two flanks) when raycast_size > 0
			var raycast_count : int = 1
			if raycast_size > 0.0:
				raycast_count = 3
			for i in range(raycast_count):
				
				var skip : bool = false
				
				if !from_context:
					test_cast.global_position = marker
					$RaycastBasis.global_position = test_point
					test_cast.target_position = test_point - test_cast.global_position
					if !$RaycastBasis.global_position.is_equal_approx(test_point):
						skip = true
						$RaycastBasis.look_at(test_point)
				else:
					test_cast.global_position = test_point
					$RaycastBasis.global_position = test_point
					test_cast.target_position = marker - test_cast.global_position
					if !$RaycastBasis.global_position.is_equal_approx(marker):
						skip = true
						$RaycastBasis.look_at(marker)
				
				# Update the transform so the local offsets use the new orientation
				$RaycastBasis.force_update_transform()
				
				# Offset the flank rays (i == 1 and i == 2) unless skip is set
				if i == 1 and !skip:
					test_cast.global_position += $RaycastBasis.global_transform.basis * Vector3(-raycast_size/2,0,0)
					test_cast.target_position += $RaycastBasis.global_transform.basis * Vector3(-raycast_size/2,0,0)
				if i == 2 and !skip:
					test_cast.global_position += $RaycastBasis.global_transform.basis * Vector3(raycast_size/2,0,0)
					test_cast.target_position += $RaycastBasis.global_transform.basis * Vector3(raycast_size/2,0,0)

				test_cast.force_update_transform()
				test_cast.force_raycast_update()
				
				# Not inverted: reject the point if any ray hits something
				if !raycast_invert_result:
					if test_cast.is_colliding():
						to_remove.append(marker)
						break
				else:
				# Inverted: reject the point if any ray hits nothing
					if !test_cast.is_colliding():
						to_remove.append(marker)
						break
					
	remove_elements(to_remove)

	####################
	## PATHFIND TESTS ##
	####################
	
	if check_pathfinder:
		#note; start from npc to end since we may be off grid
		for marker in marker_array:
			if pathfinder_context == null:
				nav_parent.global_position = grid_origin
			else:
				nav_parent.global_position = pathfinder_context
			pathfinder.target_position = marker
			if !pathfinder.is_target_reachable():
				to_remove.append(marker)
	
	remove_elements(to_remove)
	
	if debug_shapes:
		for marker in marker_array:
			var point = eqs_marker.instantiate()
			add_child(point)
			point.global_position = marker
			debug_array.append(point)
	
	return marker_array
	
func remove_elements(removal_array):
	for remove in removal_array:
		marker_array.erase(remove)
	removal_array.clear()
		
