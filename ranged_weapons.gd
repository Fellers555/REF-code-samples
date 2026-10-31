class_name RangedWeapons extends Weapons

var node_type = preload("res://Weapons/Ranged/ranged_weapon.tscn")
var weapon_type = WeaponEnums.WEAPON_TYPE.RANGED

@export_category("Firing")
@export var shootdelay_max : float = 8
@export var fire_type = WeaponEnums.FIRE_TYPE.SEMIAUTO
@export var fire_intensity : float = .65 
@export var ejection_timing : WeaponEnums.EJECTION_TIMING = WeaponEnums.EJECTION_TIMING.ON_FIRE

@export_category("Burst Fire")
@export var burstdelay_max : float = 0.0
@export var burstcount_max : int = 1

@export_category("Ammunition")
@export var damage : float = 1
@export var inaccuracy:float = 1
@export var pelletcount:int = 1
@export var bullet_velocity : float = 100.0
@export var casing_type : WeaponEnums.CASING_TYPE

@export_category("Capacity")
@export var max_ammo:int = 12
@export var reload_time:float = 35
@export var reload_type = WeaponEnums.RELOAD_TYPE.STANDARD

@export_category("Sound")
@export var sound : AudioStreamWAV
@export var reload_sound : AudioStreamWAV

@export_category("Visuals")
@export var model : Mesh = null
@export var weapon_scene : PackedScene = null
