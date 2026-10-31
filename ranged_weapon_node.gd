class_name Weapon extends Node3D

#projectiles to create
var bullet = preload("res://Projectiles/Bullet/bullet.tscn")
var dropped_weapon = preload("res://Projectiles/Dropped Weapon/dropped_weapon.tscn")
var casing = preload("res://Projectiles/Casing/casing.tscn")
var bash_hitbox = preload("res://Weapons/Hitboxes/melee_hitbox.tscn")
var muzzle_flash_vis = preload("res://Projectiles/Bullet/Muzzle Flash/muzzle_flash.tscn")

var bash_swing_sfx = preload("res://Weapons/Ranged/Generic Sounds/bash_swing.wav")

#weapon basics
var weapon : RangedWeapons = null
var shootdelay = 0
var shootdelay_max = 8
var inaccuracy = 0
var pelletcount : int = 1
var fire_type : WeaponEnums.FIRE_TYPE = WeaponEnums.FIRE_TYPE.SEMIAUTO
var reload_type : WeaponEnums.RELOAD_TYPE = WeaponEnums.RELOAD_TYPE.STANDARD
var max_ammo : int = 0

var reloadtimer : float = 0
var reload_time : float = 0
var fully_loaded : bool = false

var burstdelay : float = 0.0
var burstcount : int = 1

var bashtimer_max : float = 32
var bashtimer : float = 0

var weapon_state : WeaponEnums.WEAPON_STATE = WeaponEnums.WEAPON_STATE.READY

#####################
## BONE ATTACHMENT ##
#####################
var has_attachment_point : bool = false

#########################
## SIGNALS FOR ACTIONS ##
#########################

signal fired_weapon
signal bash_weapon
signal start_reload
signal start_draw

# For ON_RELOAD ejection: eject shells once per reload. If a reload is interrupted, don't eject
# until it finishes, and eject extra shells if we fired after the interruption.
var shells_ejected : int = 0

@onready var parent : WeaponUser = get_parent()
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Muzzle_Flash
@onready var reload_sound = $Reload_sound
@onready var mesh : MeshInstance3D = $BoneAttachment3D/MeshInstance3D
var muzzle_flash_vis_point : Node3D
var casing_release_point : Node3D
@onready var bullet_spawn_check = $BulletSpawnCheck
@onready var bone_attachment_point : BoneAttachment3D = $BoneAttachment3D

func _ready():
	pass

func _physics_process(delta: float) -> void:
	
	match weapon_state:
		WeaponEnums.WEAPON_STATE.READY:
			shootdelay = max(shootdelay-delta*60,0)
		WeaponEnums.WEAPON_STATE.FIRING:
			process_burst(delta)
		WeaponEnums.WEAPON_STATE.RELOAD:
			process_reload(delta)
			shootdelay = max(shootdelay-delta*60,0)
		WeaponEnums.WEAPON_STATE.BASH:
			process_bash(delta)
			shootdelay = max(shootdelay-delta*60,0)
			
	if parent.ammo >= max_ammo:
		fully_loaded = true
		
	#decrease muzzle flash intensity
	muzzle_flash.light_energy = lerp(muzzle_flash.light_energy,0.0,delta * 40)

########################
## SETUP AND CREATION ##
########################

#region

func get_weapon_stats(_weapon):
# Copy stats from the weapon resource
	if _weapon != null:
		shootdelay_max = _weapon.shootdelay_max
		fire_type = _weapon.fire_type
		inaccuracy = _weapon.inaccuracy
		pelletcount = _weapon.pelletcount
		reload_time = _weapon.reload_time
		max_ammo = _weapon.max_ammo
		reload_type = _weapon.reload_type
		
		# Use the weapon's own scene when there is a bone attachment point; otherwise fall back to the generic model
		if has_attachment_point and _weapon.weapon_scene != null:
			mesh.queue_free()
			call_deferred("add_weapon_scene")
		else:
			muzzle_flash_vis_point = mesh.get_node("MuzzleFlashParent")
			casing_release_point = mesh.get_node("CasingReleasePoint")
		
		if _weapon.model != null:
			mesh.mesh = _weapon.model

func add_weapon_scene():
	var wep_scene = weapon.weapon_scene.instantiate()
	bone_attachment_point.add_child(wep_scene)
	mesh = wep_scene
	muzzle_flash_vis_point = mesh.get_node("MuzzleFlashParent")
	casing_release_point = mesh.get_node("CasingReleasePoint")

func setup():
	get_weapon_stats(weapon)
	call_deferred("start_draw_anim")
	

func fire():
	
#	shake screen if player weapon
	if parent.is_in_group("player"):
		parent.camera_module.start_shake(weapon.fire_intensity)
		# Fixed sound propagation radius for now; could later come from the weapon (e.g. suppressors)
		AiFunctions.propagate_reactable_sound(parent.global_position,17.0)
	
#	end any in progress reloads
	if weapon_state == WeaponEnums.WEAPON_STATE.RELOAD:
		if burstcount > 1.0:
			weapon_state = WeaponEnums.WEAPON_STATE.FIRING
		else:
			weapon_state = WeaponEnums.WEAPON_STATE.READY
	
	parent.ammo -= 1
	shootdelay = shootdelay_max
	anim_player.stop()
	reload_sound.stop()
	
	if !has_attachment_point:
		anim_player.play("Fire",-1,1.0,false)
	fired_weapon.emit()
	
	#set bright light
	muzzle_flash.light_energy = 15.0
	
	#create visual effect
	var flash = muzzle_flash_vis.instantiate()
	muzzle_flash_vis_point.add_child(flash)
	
	create_bullet()
	
	if weapon.sound != null:
		#note; uses random pitch
		GlobalFunctions.play_sound_basic(parent.global_position,weapon.sound,1,randf_range(.95,1.02),true,parent)
		
	#create casing
	if weapon.ejection_timing == WeaponEnums.EJECTION_TIMING.ON_FIRE:
		eject_casing()
	
func create_bullet():
	for b in range(pelletcount):
		var bul = bullet.instantiate()
		parent.add_sibling(bul)
		
		#CHECK IF WE CAN SPAWN THE BULLET AT MUZZLE OR IF WE NEED TO GO TO START
		bullet_spawn_check.add_exception(parent)
		bullet_spawn_check.force_update_transform()
		bullet_spawn_check.force_raycast_update()
		if !bullet_spawn_check.is_colliding():
			bul.global_position = parent.global_position + bullet_spawn_check.target_position.rotated(Vector3.UP,bullet_spawn_check.global_rotation.y)
		else:
			bul.global_position = parent.global_position
		
		bul.add_collision_exception_with(parent)
		bul.global_rotation = parent.global_rotation
		bul.global_rotation_degrees.y += randf_range(-inaccuracy/2,inaccuracy/2)
		bul.parent = parent
		bul.team = parent.team
		bul.damage = weapon.damage
		bul.speed = weapon.bullet_velocity

func eject_casing():
	var case = casing.instantiate()
	case.fired_from = weapon
	parent.add_sibling(case)
	case.global_position = casing_release_point.global_position
	case.global_rotation = parent.global_rotation + Vector3(0,deg_to_rad(randf_range(-85,-95)),0)
	case.apply_central_impulse(Vector3(case.global_transform.basis.z*-randf_range(3.5,6)))
	case.apply_central_impulse(Vector3(case.global_transform.basis.y*randf_range(.5,1.5)))
	case.apply_torque_impulse(Vector3(case.global_transform.basis.x*randf_range(.3,-.3)))
	case.apply_torque_impulse(Vector3(case.global_transform.basis.y*randf_range(.3,-.3)))
	case.apply_torque_impulse(Vector3(case.global_transform.basis.z*randf_range(.3,-.3)))
	case.global_rotation = parent.global_rotation

#endregion

####################
## STATE SPECIFIC ##
####################

#region

func check_reload():
	if weapon_state == WeaponEnums.WEAPON_STATE.READY and parent.ammo < max_ammo and shootdelay == 0:
		weapon_state = WeaponEnums.WEAPON_STATE.RELOAD
		reloadtimer = reload_time
		anim_player.stop()
		if !has_attachment_point:
			anim_player.play("Reload",-1,60.0/reload_time,false)
		start_reload.emit()
			
		if weapon.ejection_timing == WeaponEnums.EJECTION_TIMING.ON_RELOAD and shells_ejected < max_ammo:
			for i in range((max_ammo - parent.ammo)-shells_ejected):
				shells_ejected += 1
				eject_casing()
		
		#alert enemies of reload 
		if parent.is_in_group("player"):
			# Reload noise alerts enemies at a shorter range than gunfire
			AiFunctions.propagate_reactable_sound(parent.global_position,11.0)
		
		if weapon.reload_sound != null:
			reload_sound.pitch_scale = (weapon.reload_sound.get_length() * 60)/reload_time
			reload_sound.stream = weapon.reload_sound
			reload_sound.play(0.0)	

func process_burst(delta):
	# Fires the remaining rounds of a burst, then returns to READY
	if burstcount > 0.0:
		if parent.ammo > 0:
			burstdelay = max(burstdelay-delta*60,0)
			if burstdelay == 0:
				fire()
				burstcount -= 1
				if burstcount == 0.0:
					weapon_state = WeaponEnums.WEAPON_STATE.READY
				else:
					burstdelay = weapon.burstdelay_max
		else:
			weapon_state = WeaponEnums.WEAPON_STATE.READY
	else:
		weapon_state = WeaponEnums.WEAPON_STATE.READY

func process_reload(delta):
	reloadtimer = max(reloadtimer-delta*60,0)
	if reloadtimer == 0:
		match reload_type:
#				magazines
			WeaponEnums.RELOAD_TYPE.STANDARD:
				parent.ammo = max_ammo
				shells_ejected = 0
				weapon_state = WeaponEnums.WEAPON_STATE.READY
				parent.weapon_reload_completed()
#				shotgun shells
			WeaponEnums.RELOAD_TYPE.ROUNDS:
				parent.ammo += 1 
				if parent.ammo == max_ammo:
					weapon_state = WeaponEnums.WEAPON_STATE.READY
					#note: may need to do a -= 1 instead for something like an SAA
					shells_ejected = 0
					parent.weapon_reload_completed()
				else:
					anim_player.stop()
					if !has_attachment_point:
						anim_player.play("Reload",-1,60.0/reload_time,false)
					start_reload.emit()
					reloadtimer = reload_time
					
					if weapon.reload_sound != null:
						reload_sound.pitch_scale = (weapon.reload_sound.get_length() * 60)/reload_time
						reload_sound.stream = weapon.reload_sound
						reload_sound.play(0.0)	

func process_bash(delta):
	bashtimer = GlobalFunctions.timer_countdown(bashtimer,delta)
	if bashtimer == 0.0:
		weapon_state = WeaponEnums.WEAPON_STATE.READY

#endregion

#######################
## CHECK FOR ACTIONS ##
#######################

#region

func check_fire():
	
	var to_fire = false
	
	if (weapon_state == WeaponEnums.WEAPON_STATE.RELOAD or weapon_state == WeaponEnums.WEAPON_STATE.READY) and shootdelay == 0.0 and parent.ammo > 0:
		match reload_type:
			WeaponEnums.RELOAD_TYPE.STANDARD:
				if !weapon_state == WeaponEnums.WEAPON_STATE.RELOAD:
					fire()
					to_fire = true
			# Round-by-round reloads can be interrupted by firing
			WeaponEnums.RELOAD_TYPE.ROUNDS:
				fire()
				to_fire = true
	
#	apply burst stats only on first fire check
	if to_fire:
		if fire_type == WeaponEnums.FIRE_TYPE.BURST:
			weapon_state = WeaponEnums.WEAPON_STATE.FIRING
			burstcount = weapon.burstcount_max - 1
			burstdelay = weapon.burstdelay_max
	
	return to_fire

func drop_weapon():
	var wep = dropped_weapon.instantiate()
	wep.weapon = weapon
	wep.ammo = parent.ammo
	parent.add_sibling(wep)
	wep.global_position = parent.global_position
#	apply some physics for drop
	wep.apply_central_impulse(Vector3(parent.global_transform.basis.z*-3))
	wep.apply_torque_impulse(Vector3(parent.global_transform.basis.x*randf_range(.1,-.1)))
	wep.apply_torque_impulse(Vector3(parent.global_transform.basis.y*randf_range(.1,-.1)))
	wep.apply_torque_impulse(Vector3(parent.global_transform.basis.z*randf_range(.1,-.1)))
	
	parent.clear_weapon()
	
#	remove weapon so stuff like firing doesn't process
	weapon_state = WeaponEnums.WEAPON_STATE.READY
	queue_free()

func start_bash():
	#stops reloads
	if shootdelay == 0.0 and weapon_state != WeaponEnums.WEAPON_STATE.BASH:
		
		GlobalFunctions.play_sound_basic(parent.global_position,bash_swing_sfx,1,randf_range(.9,.98),true,parent)
		
		reload_sound.stop()
		anim_player.stop()
		
		if parent.is_in_group("player"):
			parent.camera_module.start_shake(.9)
		
		weapon_state = WeaponEnums.WEAPON_STATE.BASH
		if !has_attachment_point:
			anim_player.play("Bash",-1,anim_player.get_animation("Bash").length*60/bashtimer_max,false)
		bash_weapon.emit()
		bashtimer = bashtimer_max
		
		var hitbox = bash_hitbox.instantiate()
		add_sibling(hitbox)
		hitbox.global_rotation = parent.global_rotation + Vector3(0,deg_to_rad(-90),0)
		hitbox.setup(parent)
		
		return true
	return false
		
func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	pass

#endregion

################
## MISC ANIMS ##
################

func start_draw_anim():
	start_draw.emit()

func warn_anim():
	anim_player.stop()
	if !has_attachment_point:
		anim_player.play("Warn",-1,1.0,false)
