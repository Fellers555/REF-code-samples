class_name EnemyAttackSubstates extends NpcSubstates

#################################
## SUBSTATE SPECIFIC FUNCTIONS ##
#################################

#region

#ATTACK DELAY
var attack_delay_timer : float = 0.0
var attack_delay_timer_min : float = 25.0
var attack_delay_timer_max : float = 90.0

#WARN
var warn_timer : float = 0
var base_warn_timer : float = 45.0

#HOLD
var attack_to_chase_delay : float = 0.0
var attack_to_chase_delay_min : float = 20.0
var attack_to_chase_delay_max : float = 35.0

var cover_chance_percentage = 75
var can_roll_for_cover : bool = false

#COVER
var max_cover_distance : float = 24.0
var cover_distance_timeout : float = 0.0
var cover_distance_timeout_min : float = 90.0
var cover_distance_timeout_max : float = 300.0
var reached_cover : bool = false
var cover_wait_timer : float = 0.0
var cover_wait_min : float = 30.0
var cover_wait_max : float = 120.0

#endregion

#############
## ENTRIES ##
#############

#region

# TODO: handle cases where a target can't be reached

func attack_delay_entry():
	enemy.pathfinding_module.stop_path()
	attack_delay_timer = randf_range(attack_delay_timer_min,attack_delay_timer_max)

func warn_entry():
	enemy.speech_module.play_voice_line("CONTACT!", 75.0, true)
	
	enemy.pathfinding_module.stop_path()
	
	warn_timer = base_warn_timer
	if enemy.weapon != null:
		enemy.weapon_node.warn_anim()
	if enemy.squad != null:
		enemy.squad.update_readiness(Squad.READINESS.COMBAT)

func hold_entry():
	enemy.pathfinding_module.stop_path()
	
	if enemy.weapon == null or enemy.get_ammo_percentage()  > .33:
		can_roll_for_cover = true
		
	hold_entry_spacing_check(3.0)

func chase_entry():
	var chase_point = enemy.eqs_module.get_chase_point(enemy.target_last_known_pos,3.0)
	if chase_point != null:
		enemy.pathfinding_module.start_path(chase_point)
	else:
		# No valid chase point: fall back to pathing directly to the last known position
		enemy.pathfinding_module.start_path(enemy.target_last_known_pos)
		# Tested: works well enough since this case is rare. The enemy reaches a nearby point,
		# times out correctly, and repaths if a teammate spots the player.
		# Known limitation: enemies can stack up since they all go to the last known position.

func cover_entry():
	#set timeout so that if we get an invalid point we don't try to get to cover again and again and instead wait
	cover_distance_timeout = randf_range(cover_distance_timeout_min,cover_distance_timeout_max)
	
	cover_wait_timer = randf_range(cover_wait_min,cover_wait_max)
	var did_not_find_cover = true
	if enemy.los_module.line_of_sight > LosModule.VISIBILITY.NONE or enemy.flinching:
		var cover_point = enemy.eqs_module.get_cover_point(enemy.global_position,enemy.target_last_known_pos,3.0)
		if cover_point != null:
			did_not_find_cover = false
			enemy.speech_module.play_voice_line("COVER!", 65.0, false)
			enemy.pathfinding_module.start_path(cover_point)
	if randi_range(0,1) == 1:
		enemy.speech_module.play_voice_line("HOLDING!", 65.0, false)
	reached_cover = did_not_find_cover
	
func cover_close_entry():
	#same as above
	cover_distance_timeout = randf_range(cover_distance_timeout_min,cover_distance_timeout_max)
	
	cover_wait_timer = randf_range(cover_wait_min,cover_wait_max)
	var did_not_find_cover = true
	if enemy.los_module.line_of_sight > LosModule.VISIBILITY.NONE or enemy.global_position.distance_to(enemy.target_last_known_pos) > max_cover_distance or enemy.flinching:
		var cover_point = enemy.eqs_module.get_cover_point(enemy.target_last_known_pos,enemy.target_last_known_pos,3.0)
		if cover_point != null:
			enemy.speech_module.play_voice_line("I'M TAKING COVER!", 65.0, false)
			did_not_find_cover = false
			enemy.pathfinding_module.start_path(cover_point)
	if randi_range(0,1) == 1:
		enemy.speech_module.play_voice_line("HOLDING!", 65.0, false)
	reached_cover = did_not_find_cover	

#endregion

###############
## PROCESSES ##
###############

#region

func attack_delay_process(delta):
	attack_delay_timer = GlobalFunctions.timer_countdown(attack_delay_timer,delta)
	if enemy.los_module.line_of_sight > LosModule.VISIBILITY.NONE:
		enemy.look_target_module.set_look_position(enemy.target_last_known_pos)
	if attack_delay_timer == 0.0 or enemy.flinching:
		enemy.determine_attack_on_role()

func warn_process(delta):
	if enemy.los_module.line_of_sight > enemy.los_module.VISIBILITY.NONE:
		enemy.look_target_module.set_look_position(enemy.target_last_known_pos)
		
	warn_timer = GlobalFunctions.timer_countdown(warn_timer,delta)
	if warn_timer == 0.0:
		enemy.determine_attack_on_role()

func hold_process(delta):
	
	#PREVENTS FLICKING BACK AND FORTH FOR COVER ENEMIES RETREATING
	if enemy.los_module.reacted_to_target:
		enemy.attacking_target = true
	
	if enemy.los_module.line_of_sight > LosModule.VISIBILITY.NONE:
		enemy.look_target_module.set_look_position(enemy.target_last_known_pos)
	
	#STATE TRANSFER
	# Known limitations: engagement distance is approximate, and the player can still
	# shoot enemies from outside their sight.
	if enemy.los_module.line_of_sight < enemy.los_module.VISIBILITY.CENTER or enemy.target_last_known_pos.distance_to(enemy.global_position) > enemy.engagement_distance:
		attack_to_chase_delay = GlobalFunctions.timer_countdown(attack_to_chase_delay,delta)
		if attack_to_chase_delay == 0.0:
			#IF WE DON'T HAVE A LOT OF AMMO TRY TO RELOAD
			if enemy.get_ammo_percentage() < .45 and !enemy.weapon_actions_module.reloading:
				#RANDOM CHANCE: WE CAN EITHER PURSUE OR LET SOMEONE ELSE TAKE OVER, RUN ONLY ONCE
				var rand = randi_range(0,2)
				if rand == 0:
					enemy.speech_module.play_voice_line("COVER ME!", 65.0, false)
					enemy.squad.assign_squadmember_role(enemy,AiFunctions.SQUAD_ROLE.COVER)
					enemy.set_ai_state(Enemy.AI_STATE.ATTACK,Enemy.ATTACK_SUBSTATES.COVER)
				else:
					enemy.speech_module.play_voice_line("RELOADING!", 65.0, false)
					enemy.weapon_actions_module.check_weapon_reload()
					
			#OTHERWISE PUSH IN
			elif !enemy.weapon_actions_module.reloading:
				enemy.speech_module.play_voice_line("I'M MOVING IN!", 65.0, false)
				enemy.set_ai_state(enemy.AI_STATE.ATTACK,enemy.ATTACK_SUBSTATES.CHASE)
	else:
		#NO ATTACKING OUTSIDE OF ENGAGEMENT DISTANCE
		enemy.weapon_actions_module.check_attack_weapon_actions(enemy.target,true,LosModule.VISIBILITY.PARTIAL)
		#CHECK FOR RELOAD EVEN IF NO CLEAR FIRE BUT ZERO AMMO
		if enemy.get_ammo_percentage() == 0.0:
			enemy.weapon_actions_module.check_weapon_reload()
		if enemy.weapon != null and enemy.get_ammo_percentage() < .33:
			roll_for_cover()
		
		attack_to_chase_delay = randf_range(attack_delay_timer_min,attack_delay_timer_max)

func chase_process(_delta):
	
	#PROCESS TIMEOUT
	if enemy.ai_substate == enemy.ATTACK_SUBSTATES.CHASE_TIMEOUT:
		if enemy.squad != null:
			enemy.squad.start_combat_timeout()
	
	#REPATH CHECKS; TRIGGERS ON SOUND OR OTHER FRIENDLY LOS/FLINCH
	if (!enemy.los_module.check_2_points_los(enemy.pathfinding_module.nav_agent.target_position,enemy.target_last_known_pos) 
	or enemy.pathfinding_module.nav_agent.target_position.distance_to(enemy.target_last_known_pos) > enemy.engagement_distance):
		enemy.set_ai_state(enemy.AI_STATE.ATTACK,enemy.ATTACK_SUBSTATES.CHASE)
		if enemy.squad != null:
			enemy.squad.stop_combat_timeout()
	
	#PREAIM THE TARGET
	if enemy.los_module.reacted_to_target or enemy.los_module.check_2_points_los(enemy.global_position,enemy.target_last_known_pos) or enemy.los_module.line_of_sight > LosModule.VISIBILITY.NONE:
		enemy.look_target_module.set_look_position(enemy.target_last_known_pos)
	else:
		if enemy.pathfinding_module.using_path: enemy.pathfinding_module.look_path_direction()
	
	#STATE TRANSFER
	if enemy.los_module.line_of_sight == enemy.los_module.VISIBILITY.CENTER and enemy.target_last_known_pos.distance_to(enemy.global_position) < enemy.engagement_distance:
		enemy.set_ai_state(enemy.AI_STATE.ATTACK,enemy.ATTACK_SUBSTATES.HOLD)

func cover_process(_delta):
	#CHECK IF WE CAN ATTACK
	if (enemy.los_module.reacted_to_target and (enemy.weapon == null or enemy.ammo > 0)
	and enemy.target_last_known_pos.distance_to(enemy.global_position) < enemy.engagement_distance):
		if enemy.squad == null or enemy.squad.get_current_number_of_attackers() < enemy.squad.max_attackers:
			enemy.attacking_target = true
	
	#DETERMINE WHETHER TO LOOK AND SHOOT
	if enemy.attacking_target or enemy.recently_attacked:
		enemy.look_target_module.set_look_position(enemy.target_last_known_pos)
		enemy.weapon_actions_module.check_attack_weapon_actions(enemy.target,false,LosModule.VISIBILITY.PARTIAL)
	else:
		if enemy.pathfinding_module.using_path: enemy.pathfinding_module.look_path_direction()
	
	
	# While moving to cover
	if !reached_cover:
		# If we're only moving to cover but are fully stocked on ammo, join the fight
		if !enemy.last_man_in_squad and enemy.squad.queue_for_attack_position(enemy) and enemy.get_ammo_percentage() > .95:
			enemy.speech_module.play_voice_line("SUPPORTING!", 65.0, false)
			enemy.squad.assign_squadmember_role(enemy,AiFunctions.SQUAD_ROLE.ATTACK)
			enemy.set_ai_state(Enemy.AI_STATE.ATTACK,Enemy.ATTACK_SUBSTATES.HOLD)
	
	#QUEUE TO JOIN OR TRY TO RUN
	else:
		#RELOCATE IF TOO FAR FROM PLAYER
		if enemy.global_position.distance_to(enemy.target_last_known_pos) > max_cover_distance:
			cover_distance_timeout = GlobalFunctions.timer_countdown(cover_distance_timeout,_delta)
			if cover_distance_timeout == 0.0:
				enemy.speech_module.play_voice_line("REPOSITIONING!",65.0, false)
				enemy.set_ai_state(Enemy.AI_STATE.ATTACK,Enemy.ATTACK_SUBSTATES.COVER_CLOSE)
		else:
			cover_distance_timeout = randf_range(cover_distance_timeout_min,cover_distance_timeout_max)
		
		#LOOK AT ENEMY IF WE MADE IT AND SPOTTED, EVEN IF WE CAN'T SHOOT
		if enemy.los_module.line_of_sight > LosModule.VISIBILITY.NONE:
			enemy.look_target_module.set_look_position(enemy.target_last_known_pos)
		
		#RELOAD IF WE HAVEN'T SEEN THE ENEMY IN A BIT OR WE HAVE NO CHOICE
		if !enemy.recently_attacked or enemy.get_ammo_percentage() == 0:
			enemy.weapon_actions_module.check_weapon_reload()
		
		cover_wait_timer = GlobalFunctions.timer_countdown(cover_wait_timer,_delta)
		
		if cover_wait_timer == 0.0:
			#TRY TO ATTACK IF WE HAVE ENOUGH AMMO AND WE AREN't RELOADING, AND ALSO AREN'T THE LAST MAN
			if !enemy.last_man_in_squad and enemy.squad.queue_for_attack_position(enemy) and enemy.get_ammo_percentage() > .65 and !enemy.weapon_actions_module.reloading:
				#RANDOM VOICE LINE OR COOPERATION
				var rand = randi_range(0,1)
				var commander = enemy.get_nearest_squadmate(10.0)
				if commander != null and rand == 1:
					commander.speech_module.play_voice_line("MOVE IN!", 75.0, false)
				else:
					enemy.speech_module.play_voice_line("ENGAGING!", 75.0, false)
				enemy.squad.assign_squadmember_role(enemy,AiFunctions.SQUAD_ROLE.ATTACK)
				enemy.set_ai_state(Enemy.AI_STATE.ATTACK,Enemy.ATTACK_SUBSTATES.HOLD)
				
			#OTHERWISE IF SPOTTED RUN AWAY; RUN AWAY IF RELOADING
			elif enemy.los_module.line_of_sight > LosModule.VISIBILITY.NONE:
				if !enemy.last_man_in_squad: enemy.speech_module.play_voice_line("HES ON ME!",65.0, false)
				enemy.set_ai_state(Enemy.AI_STATE.ATTACK, Enemy.ATTACK_SUBSTATES.COVER)

#endregion

##############################
## INTERNAL STATE FUNCTIONS ##
##############################

func roll_for_cover():
	if can_roll_for_cover:
		can_roll_for_cover = false
		var random_result = randf_range(0,100)
		if random_result <= cover_chance_percentage:
			if enemy.squad != null:
				enemy.squad.assign_squadmember_role(enemy,AiFunctions.SQUAD_ROLE.COVER)
			enemy.set_ai_state(enemy.AI_STATE.ATTACK,enemy.ATTACK_SUBSTATES.COVER)

func hold_entry_spacing_check(spacing):
	var should_relocate : bool = false
	if enemy.squad != null:
		for unit in enemy.squad.squadmembers:
			if unit != enemy and !unit.pathfinding_module.using_path and unit.global_position.distance_to(enemy.global_position) < spacing:
				should_relocate = true
				break;
	if should_relocate:
		var strafe_point = enemy.eqs_module.get_chase_point(enemy.target_last_known_pos,spacing)
		if strafe_point != null:
			enemy.pathfinding_module.start_path(strafe_point)
		else:
			enemy.pathfinding_module.stop_path()
	else:
		enemy.pathfinding_module.stop_path()
