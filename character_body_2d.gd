extends CharacterBody2D

## ---------- Movement tuning ----------
@export var max_speed: float = 240.0
@export var accel_ground: float = 2200.0
@export var accel_air: float = 1400.0
@export var friction: float = 2400.0

@export var gravity: float = 1400.0
@export var fall_gravity_mult: float = 1.35

@export var jump_speed: float = 520.0
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.10
@export var jump_cut_mult: float = 0.55

## ---------- Invert gimmick ----------
@export var invert_cooldown: float = 0.20
@export var snap_distance: float = 2000.0  # Increased range for safety
@export var snap_margin: float = 2.0       # Tiny gap from the tile surface
@export var player_height_offset: float = 16.0 # HALF of your collision height

# Collision layers (bitmasks): layer1=1, layer2=2
@export var surface_mask: int = 1   # SurfaceLayer (Black blocks)
@export var beneath_mask: int = 2   # BeneathLayer (White blocks)

# Colors
@export var normal_color: Color = Color.BLACK
@export var inverted_color: Color = Color.WHITE

@onready var anim: AnimatedSprite2D = _get_anim()

var inverted: bool = false
var invert_timer: float = 0.0
var coyote_timer: float = 0.0
var buffer_timer: float = 0.0

func _ready() -> void:

	if anim == null:
		push_error("Player.gd: No AnimatedSprite2D found!")
	else:
		_safe_play("idle")

func _physics_process(delta: float) -> void:
	invert_timer = maxf(0.0, invert_timer - delta)

	# The "Invert" Action
	if Input.is_action_just_pressed("invert") and invert_timer <= 0.0:
		invert_timer = invert_cooldown
		_do_invert()

	_update_timers(delta)
	_handle_horizontal(delta)
	_apply_gravity(delta)
	_handle_jump()
	_apply_jump_cut()

	move_and_slide()
	_update_animation()

# -------------------- Core gimmick --------------------

func _do_invert() -> void:
	inverted = !inverted
	surface_mask = 2
	beneath_mask = 1
	

	# Zero out velocity so the transition feels snappy
	velocity.y = 0.0

	# Move the player to the new world's floor/ceiling


func _gravity_sign() -> float:
	return 1.0 if !inverted else -1.0

func _snap_to_new_support() -> void:
	var space := get_world_2d().direct_space_state
	var origin := global_position
	var dir := Vector2.DOWN * _gravity_sign()
	var target := origin + dir * snap_distance

	# Create Raycast Query
	var q := PhysicsRayQueryParameters2D.create(origin, target)
	q.exclude = [self]
	
	# IMPORTANT: Raycast must ONLY look for the layer we just switched to
	q.collision_mask = collision_mask 

	var hit := space.intersect_ray(q)
	
	if not hit.is_empty():
		var hit_pos: Vector2 = hit["position"]
		# Teleport: Position = Hit point - (gravity_direction * (gap + half_player_height))
		# This places your feet/head exactly on the surface
		global_position = hit_pos - dir * (snap_margin + player_height_offset)

# -------------------- Movement & Animation --------------------

func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	buffer_timer = maxf(0.0, buffer_timer - delta)
	if Input.is_action_just_pressed("jump"):
		buffer_timer = jump_buffer

func _handle_horizontal(delta: float) -> void:
	var input_dir: float = Input.get_axis("move_left", "move_right")
	var target_x: float = input_dir * max_speed
	var a: float = accel_ground if is_on_floor() else accel_air

	if absf(input_dir) > 0.01:
		velocity.x = move_toward(velocity.x, target_x, a * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

func _apply_gravity(delta: float) -> void:
	var g := gravity
	if velocity.y * _gravity_sign() > 0.0:
		g *= fall_gravity_mult
	velocity.y += g * _gravity_sign() * delta

func _handle_jump() -> void:
	if buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = -jump_speed * _gravity_sign()
		buffer_timer = 0.0
		coyote_timer = 0.0

func _apply_jump_cut() -> void:
	if Input.is_action_just_released("jump") and (velocity.y * _gravity_sign() < 0.0):
		velocity.y *= jump_cut_mult

func _update_animation() -> void:
	if anim == null: return
	
	if absf(velocity.x) > 5.0:
		anim.flip_h = velocity.x < 0.0

	if is_on_floor():
		_safe_play("run" if absf(velocity.x) > 10.0 else "idle")
	else:
		_safe_play("jump" if velocity.y * _gravity_sign() < 0.0 else "fall")

func _safe_play(anim_name: String) -> void:
	if anim.sprite_frames.has_animation(anim_name) and anim.animation != anim_name:
		anim.play(anim_name)

func _get_anim() -> AnimatedSprite2D:
	var n = get_node_or_null("Anim")
	if n is AnimatedSprite2D: return n
	return _find_anim_recursive(self)

func _find_anim_recursive(node: Node) -> AnimatedSprite2D:
	for c in node.get_children():
		if c is AnimatedSprite2D: return c
		var found = _find_anim_recursive(c)
		if found: return found
	return null
