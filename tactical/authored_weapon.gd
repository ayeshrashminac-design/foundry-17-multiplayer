@tool
extends Node3D
# Original authored hand poses stay attached to their matching weapon.
@export var idle_clip := ""
@export var walk_clip := ""
@export var run_clip := ""
@export var equip_clip := ""
@export var fire_clip := ""
@export var reload_clip := ""
@export var weapon_bone := ""
@export var hand_meshes: Array[String] = []
@export var hidden_meshes: Array[String] = []
@export var spare_magazine := ""
@export var freeze_idle := false
@export var body_scale := 1.0
@onready var animation: AnimationPlayer = $GunModel.find_child("AnimationPlayer",true,false)
@onready var skeleton: Skeleton3D = $GunModel.find_child("Skeleton3D",true,false)
var actor: CharacterBody3D
var clip := ""
var clock := 0.0
var shot_left := 0.0
var bone := -1
var idle_weapon := Transform3D.IDENTITY
var marker_rest: Dictionary = {}
var previous: Array[Transform3D] = []
var spare: Node3D
var muzzle_fx: Node3D
var first_person := false
var arms: Array[Dictionary] = []
var bone_lookup: Dictionary = {}
var character_arms: Node3D
const IK = preload("res://tactical/limb_ik.gd")

func _ready() -> void:
 var parent := get_parent()
 first_person = parent.name == "ViewWeapon"
 for i in skeleton.get_bone_count():
  var name := String(skeleton.get_bone_name(i))
  if "_end_" in name: continue
  bone_lookup[name.substr(0,name.rfind("_"))] = i
 if not first_person: scale = Vector3.ONE * body_scale
 if Engine.is_editor_hint():
  for name in hand_meshes:
   var mesh = $GunModel.find_child(name,true,false)
   if mesh: mesh.visible = first_person
  animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  animation.play(idle_clip)
  animation.seek(0,true)
  animation.pause()
  return
 while parent and not parent is CharacterBody3D: parent = parent.get_parent()
 actor = parent
 animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for name in hand_meshes:
  var mesh = $GunModel.find_child(name,true,false)
  if mesh: mesh.visible = first_person
 for mesh in $GunModel.find_children("*","MeshInstance3D",true,false):
  if first_person: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for surface in mesh.mesh.get_surface_count():
   var original = mesh.get_active_material(surface)
   if original is StandardMaterial3D:
    if first_person and String(mesh.name) in hand_meshes and original.normal_texture:
     var hands := ShaderMaterial.new()
     hands.shader = preload("res://tactical/operator_hands.gdshader")
     hands.set_shader_parameter("albedo_map",original.albedo_texture)
     hands.set_shader_parameter("normal_map",original.normal_texture)
     hands.set_shader_parameter("normal_strength",original.normal_scale)
     mesh.set_surface_override_material(surface,hands)
     continue
    var material = original.duplicate()
    material.roughness = maxf(0.48,material.roughness)
    mesh.set_surface_override_material(surface,material)
 spare = $GunModel.find_child(spare_magazine,true,false) if not spare_magazine.is_empty() else null
 animation.play(idle_clip)
 animation.seek(0,true)
 animation.pause()
 for side in ["L","R"]:
  var chain := {"upper":-1,"lower":-1,"hand":-1,"side":side}
  for i in skeleton.get_bone_count():
   var n := String(skeleton.get_bone_name(i))
   if n.begins_with("UpArm_"+side): chain.upper=i
   elif n.begins_with("Forearm_"+side): chain.lower=i
   elif n.begins_with("Hand_"+side): chain.hand=i
  if chain.upper>=0 and chain.lower>=0 and chain.hand>=0: arms.append(chain)
 bone = skeleton.find_bone(weapon_bone)
 idle_weapon = global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(bone)
 for point in [$MuzzlePoint,$ShellEjectPoint,$RightGrip,$LeftGrip]: marker_rest[point] = point.transform
 if has_node("StockContact"): marker_rest[$StockContact] = $StockContact.transform
 # The old solid sphere is replaced with a short, transparent combustion burst.
 $MuzzlePoint/MuzzleFlash.mesh = null
 muzzle_fx = Node3D.new()
 muzzle_fx.set_script(preload("res://tactical/muzzle_fx.gd"))
 $MuzzlePoint.add_child(muzzle_fx)
 $MuzzlePoint/AudioSource.bus = "SFX"
 $MuzzlePoint/AudioSource.max_polyphony = 3

func recoil_factor() -> float: return 0.55

func set_character(value: int) -> void:
 if not first_person: return
 if is_instance_valid(character_arms):
  remove_child(character_arms)
  character_arms.queue_free()
  character_arms = null
 var catalog = preload("res://mvp/character_catalog.gd")
 var path: String = catalog.OPERATORS[catalog.valid_id(value)].arms
 for mesh_name in hand_meshes:
  var mesh = $GunModel.find_child(mesh_name,true,false)
  if mesh: mesh.visible = path.is_empty()
 if path.is_empty(): return
 character_arms = Node3D.new()
 character_arms.name = "SelectedCharacterArms"
 character_arms.set_script(preload("res://tactical/character_arms.gd"))
 add_child(character_arms)
 character_arms.setup(self,path)
 character_arms.update_pose()

func authored_hand(side: String) -> Dictionary:
 var indices: Dictionary = {}
 if bone_lookup.has("Hand_"+side): indices["wrist"] = bone_lookup["Hand_"+side]
 for entry in ["005","009","017"]:
  var key: String = "Bone_"+side+"."+entry
  if bone_lookup.has(key): indices[entry] = bone_lookup[key]
 if indices.size() != 4: return {}
 var wrist: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(indices.wrist).origin)
 var middle: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(indices["009"]).origin)
 var index: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(indices["005"]).origin)
 var pinky: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(indices["017"]).origin)
 var forward := (middle-wrist).normalized()
 var across := (index-pinky).normalized()
 across = (across-forward*across.dot(forward)).normalized()
 var palm := wrist.lerp(middle,0.65)
 # A full-body arm reaches the rear of the handguard; FPS rigs use longer arms.
 if not first_person and side == "L" and has_node("StockContact"):
  palm += global_basis * Vector3(0,0,0.15)
 return {"basis":Basis(forward,across,forward.cross(across)),"palm":palm}

func authored_finger_direction(side: String, finger: String, segment: int) -> Vector3:
 var first: int = {"Index":5,"Middle":9,"Ring":13,"Pinky":17,"Thumb":20}[finger]
 var key := "Bone_"+side+".%03d" % (first+segment)
 if not bone_lookup.has(key): return Vector3.ZERO
 var i: int = bone_lookup[key]
 var children := skeleton.get_bone_children(i)
 if children.is_empty(): return Vector3.ZERO
 return (skeleton.global_basis*(skeleton.get_bone_global_pose(children[0]).origin-skeleton.get_bone_global_pose(i).origin)).normalized()
func fire() -> void:
 shot_left = actor.weapons.DATA[actor.weapons.slot].interval
 muzzle_fx.burst()
func reset_visual() -> void:
 shot_left = 0
 previous.clear()
func _exit_tree() -> void:
 if Engine.is_editor_hint(): return
 $MuzzlePoint/AudioSource.stop()
 $MuzzlePoint/AudioSource.stream = null

func animate(_reload_amount: float, _recoil: float) -> void:
 if not actor or not is_visible_in_tree(): return
 var delta := get_process_delta_time()
 var spec = actor.weapons.DATA[actor.weapons.slot]
 var velocity: Vector3 = actor.velocity if actor.local_player or multiplayer.is_server() else actor.remote_velocity
 var speed := Vector2(velocity.x,velocity.z).length()
 clock += delta*clampf(speed/4.5,0.6,1.7)
 shot_left = maxf(0,shot_left-delta)
 var next := idle_clip
 var time := 0.0
 if actor.is_reloading:
  next = reload_clip
  time = clampf(1.0-actor.reload_timer/spec.reload,0,1)*animation.get_animation(next).length
 elif shot_left > 0:
  next = fire_clip
  time = (1.0-shot_left/spec.interval)*animation.get_animation(next).length
 else:
  if not actor.is_aiming and actor.animation_grounded() and speed>0.35:
   next = run_clip if actor.sprint else walk_clip
  time = 0.0 if (actor.is_aiming or freeze_idle) and next == idle_clip else fmod(clock,animation.get_animation(next).length)
 if clip != next:
  clip = next
  animation.play(clip)
  animation.pause()
 skeleton.clear_bones_global_pose_override()
 animation.seek(time,true)
 # Blend local poses, preserving skinning and the artist's finger/hand relationship.
 for index in skeleton.get_bone_count():
  var target := skeleton.get_bone_pose(index)
  if previous.size() <= index: previous.append(target)
  else: previous[index] = previous[index].interpolate_with(target,1.0-exp(-28.0*delta))
  skeleton.set_bone_pose(index,previous[index])
 if spare: spare.visible = actor.is_reloading
 var current: Transform3D = global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(bone)
 var motion := current*idle_weapon.affine_inverse()
 for point in marker_rest: point.transform = motion*marker_rest[point]

 if first_person:
  # Anchor shoulders below the camera while preserving authored wrists/fingers.
  # Moving the whole imported FPS rig for ADS otherwise puts a shoulder across the lens.
  for chain in arms:
   var sign_x: float = 1.0 if chain.side == "R" else -1.0
   var hand := skeleton.get_bone_global_pose(chain.hand)
   var shoulder := skeleton.to_local(actor.camera.to_global(Vector3(sign_x*0.24,-0.43,-0.08)))
   var elbow := skeleton.to_local(actor.camera.to_global(Vector3(sign_x*0.35,-0.34,-0.2)))
   IK.solve(skeleton,chain.upper,chain.lower,chain.hand,hand.origin,elbow,shoulder,hand.basis)
  if is_instance_valid(character_arms): character_arms.update_pose()
