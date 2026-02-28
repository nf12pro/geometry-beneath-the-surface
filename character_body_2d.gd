extends CharacterBody2D

# ---------- Movement tuning ----------
@export var max_speed: float = 240.0
@export var accel_ground: float = 2200.0
@export var accel_air: float = 1400.0
@export var friction: float = 2400.0

@export var gravity: float = 1400.0
@export var fall_gravity_mult: float = 1.35

@export var jump_speed: float = 520.0
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.10
@export var jump_cut_mult: float = 0.55  # tap jump shorter

# ---------- Invert gimmick ----------
@export var invert_cooldown: float = 0.20
@export var snap_distance: float = 1200.0  # how far to look for new ground/ceiling
@export var snap_margin: float = 2.0       # tiny gap so we don't embed in surfaces

# Collision layers (bitmasks): layer1=1, layer2=2
@export var surface_mask: int = 1   # collide with Surface platforms (layer 1)
@export var beneath_mask: int = 2   # collide with Beneath platforms (layer 2)

# Colors
@export var normal_color: Color = Color.BLACK
@export var inverted_color: Color = Color.WHITE

@onready var anim: AnimatedSprite2D = _get_anim()

var inverted: bool = false
var invert_timer: float = 0.0

var coyote_timer: float = 0.0
var buffer_timer: float = 0.0

func _ready() -> void:
	_apply_mode()
	if anim == null:
		push_error("Player.gd: No AnimatedSprite2D found under Player. Add one (recommended name: 'Anim').")
	else:
		# Start animation safely
		_safe_play("idle")

func _physics_process(delta: float) -> void:
	invert_timer = maxf(0.0, invert_timer - delta)

	# Invert on Space (invert action)
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
	_apply_mode()

	# Optional: zero vertical velocity so flip feels controlled
	velocity.y = 0.0

	# Snap onto the new "ground" (ceiling when inverted)
	_snap_to_new_support()

func _apply_mode() -> void:
	# 1) Gravity orientation for floor detection
	up_direction = Vector2.UP if !inverted else Vector2.DOWN

	# 2) Swap what is SOLID vs PASSTHROUGH (player collision mask)
	# Normal -> collide with surface only
	# Inverted -> collide with beneath only
	collision_mask = surface_mask if !inverted else beneath_mask

	# 3) Visual flip + color
	if anim != null:
		anim.flip_v = inverted
		anim.modulate = inverted_color if inverted else normal_color

func _gravity_sign() -> float:
	# normal: gravity pulls down (+y). inverted: pulls up (-y)
	return 1.0 if !inverted else -1.0

func _snap_to_new_support() -> void:
	var space := get_world_2d().direct_space_state
	var origin := global_position
	var dir := Vector2.DOWN * _gravity_sign()  # direction gravity pulls
	var target := origin + dir * snap_distance

	var q := PhysicsRayQueryParameters2D.create(origin, target)
	q.exclude = [self]
	q.collide_with_areas = false
	q.collide_with_bodies = true

	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return

	var hit_pos: Vector2 = hit["position"]
	# Move player just off the surface, opposite the gravity direction
	global_position = hit_pos - dir * snap_margin

# -------------------- Movement helpers --------------------
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
	# stronger when falling (in the gravity direction)
	if velocity.y * _gravity_sign() > 0.0:
		g *= fall_gravity_mult
	velocity.y += g * _gravity_sign() * delta

func _handle_jump() -> void:
	# Jump opposite gravity
	if buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = -jump_speed * _gravity_sign()
		buffer_timer = 0.0
		coyote_timer = 0.0

func _apply_jump_cut() -> void:
	# If rising (against gravity) and release jump, cut jump short
	if Input.is_action_just_released("jump") and (velocity.y * _gravity_sign() < 0.0):
		velocity.y *= jump_cut_mult

# -------------------- Animation --------------------
func _update_animation() -> void:
	if anim == null or anim.sprite_frames == null:
		return

	# left/right flip
	if absf(velocity.x) > 5.0:
		anim.flip_h = velocity.x < 0.0

	if is_on_floor():
		if absf(velocity.x) > 10.0:
			_safe_play("run")
		else:
			_safe_play("idle")
	else:
		# rising is opposite gravity; falling is with gravity
		if velocity.y * _gravity_sign() < 0.0:
			_safe_play("jump")
		else:
			_safe_play("fall")

func _safe_play(name: String) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if anim.sprite_frames.has_animation(name) and anim.animation != name:
		anim.play(name)

# -------------------- Find AnimatedSprite2D --------------------
func _get_anim() -> AnimatedSprite2D:
	var n := get_node_or_null("Anim")
	if n is AnimatedSprite2D:
		return n as AnimatedSprite2D
	return _find_anim_recursive(self)

func _find_anim_recursive(node: Node) -> AnimatedSprite2D:
	for c in node.get_children():
		if c is AnimatedSprite2D:
			return c as AnimatedSprite2D
		var found := _find_anim_recursive(c)
		if found != null:
			return found
	return null
