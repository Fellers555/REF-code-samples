class_name LosModule extends RayCast3D

@export var npc : Enemy
@export var line_of_sight_shapecast : ShapeCast3D
@export var fire_path_shapecast : ShapeCast3D

@export var max_vision_range : float = 25.5

var blind : bool = false
var point_los_checker = preload("res://Management/AI Functions/Shapecasts/get_rand_point_los.tscn")

########################
## HANDLE VIS FACTORS ##
########################

@export var base_reaction_time : float = 35

enum VISIBILITY {NONE,PARTIAL,CENTER}
var line_of_sight : VISIBILITY = VISIBILITY.NONE
var reaction_time : float = base_reaction_time
var reacted_to_target : bool = false

###############
## FUNCTIONS ##
###############

func process_line_of_sight(_target,delta):
	var actual_line_of_sight = get_line_of_sight(_target)
	
	if blind:
		actual_line_of_sight = VISIBILITY.NONE
	
	if !reacted_to_target:
		line_of_sight = VISIBILITY.NONE
		
		#MAKE SURE TO COUNT UP BACK TO MAX
		if actual_line_of_sight > VISIBILITY.NONE:
			reaction_time = GlobalFunctions.timer_countdown(reaction_time,delta)
			if reaction_time == 0.0:
				reacted_to_target = true
		else:
			reaction_time = GlobalFunctions.timer_countup(reaction_time,delta,base_reaction_time)
	else:
		line_of_sight = actual_line_of_sight
		
		update_target_last_position(_target,npc.squad)
		
		#MAKE SURE TO COUNT DOWN BACK TO 0
		if actual_line_of_sight == VISIBILITY.NONE:
			reaction_time = GlobalFunctions.timer_countup(reaction_time,delta,base_reaction_time)
			if reaction_time == base_reaction_time:
				reacted_to_target = false
		else:
			reaction_time = GlobalFunctions.timer_countdown(reaction_time,delta)
			
func update_target_last_position(target,squad : Squad):
	if target != null:
		npc.target_last_known_pos = target.global_position
		if squad != null:
			squad.update_target_position(npc.target_last_known_pos,npc)

func get_line_of_sight(target):
	if target != null:
		
		if target.global_position.distance_to(global_position) > max_vision_range:
			return VISIBILITY.NONE
		
		# Avoid look_at failing when we're on top of the target
		if global_position.is_equal_approx(target.global_position):
			return VISIBILITY.CENTER
		
		################
		#ADD EXCEPTIONS#
		################
		
		clear_exceptions()
		
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			add_exception(enemy)
		
		#######################
		#CHECK FOR CENTER VIEW#
		#######################
		
		var targdist = global_position.distance_to(target.global_position)
		target_position = Vector3.ZERO
		target_position.z = max(-100.0,-targdist)
		look_at(target.global_position)
		
		force_update_transform()
		force_raycast_update()
		
		if is_colliding():
			if get_collider() == target:
				line_of_sight_shapecast.target_position.z = -targdist
				line_of_sight_shapecast.force_update_transform()
				line_of_sight_shapecast.force_shapecast_update()
				var result = line_of_sight_shapecast.is_colliding()
				if result:
					clear_exceptions()
					return VISIBILITY.PARTIAL
				clear_exceptions()
				return VISIBILITY.CENTER

		########################
		#SWEEP FOR PARTIAL VIEW#
		########################
		
		var xcount = 0
		var basexcount = 10.0
		var baseincrex = 2.0
		var increx = baseincrex
		look_at(target.global_position)
		increx = baseincrex
		xcount = 0
		while xcount < basexcount:
			force_update_transform()
			force_raycast_update()
			if is_colliding():
				if get_collider() == target:
					return VISIBILITY.PARTIAL
			# Reset aim, offset the ray by the current increment, then flip sides
			look_at(target.global_position)
			rotation_degrees.y += increx
			increx *= -1
			# After each +/- pair, count the step and widen the offset
			if increx > 0:
				xcount += 1
				increx += baseincrex
		look_at(target.global_position)
		clear_exceptions()
		return VISIBILITY.NONE
	else:
		clear_exceptions()
		return VISIBILITY.NONE

func check_clear_fire(_targ):
	if _targ != null:
		
		fire_path_shapecast.add_exception(_targ)
		fire_path_shapecast.add_exception(npc)

		fire_path_shapecast.global_rotation = global_rotation
		
		fire_path_shapecast.target_position.z = -fire_path_shapecast.global_position.distance_to(_targ.global_position)
		fire_path_shapecast.force_update_transform()
		fire_path_shapecast.force_shapecast_update()

		var result = fire_path_shapecast.is_colliding()
		fire_path_shapecast.clear_exceptions()
		
		if result:
			return false
		else:
			return true
		
	return false

func check_2_points_los(_pos1 : Vector3, _pos2 : Vector3):
	if _pos1.is_equal_approx(_pos2):
		return true
	
	var inst = point_los_checker.instantiate()
	add_sibling(inst)
	var result = inst.check_los_2_points(_pos1, _pos2)
	inst.queue_free()
	return result
