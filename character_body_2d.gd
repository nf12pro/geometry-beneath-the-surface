extends CharacterBody2D

# --- Movement tuning ---
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

# --- Animation ---
@onready var anim: AnimatedSprite2D = _get_anim()

# --- Jump feel helpers ---
var coyote_timer: float = 0.0
var buffer_timer: float = 0.0

func _ready() -> void:
	if anim == null:
		push_error("Player.gd: No AnimatedSprite2D found under Player. Add one as a child (recommended name: 'Anim').")
	else:
		# Start in a safe state
		if anim.sprite_frames != null and anim.sprite_frames.has_animation("idle"):
			anim.play("idle")

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_horizontal(delta)
	_apply_gravity(delta)
	_handle_jump()
	_apply_jump_cut()

	move_and_slide()
	_update_animation()

func _update_timers(delta: float) -> void:
	# Coyote time: allow jump shortly after leaving the ground
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	# Jump buffer: if you press jump slightly early, it still jumps
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
	var g: float = gravity
	if velocity.y > 0.0:
		g *= fall_gravity_mult
	velocity.y += g * delta

func _handle_jump() -> void:
	if buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = -jump_speed
		buffer_timer = 0.0
		coyote_timer = 0.0

func _apply_jump_cut() -> void:
	# If you release jump while rising, cut the jump short
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_mult

func _update_animation() -> void:
	if anim == null:
		return
	if anim.sprite_frames == null:
		return

	# Flip based on movement direction
	if absf(velocity.x) > 5.0:
		anim.flip_h = velocity.x < 0.0

	# Choose animation
	if is_on_floor():
		if absf(velocity.x) > 10.0:
			_safe_play("run")
		else:
			_safe_play("idle")
	else:
		if velocity.y < 0.0:
			_safe_play("jump")
		else:
			_safe_play("fall")

func _safe_play(name: String) -> void:
	# Prevents errors if an animation name is missing
	if anim.sprite_frames.has_animation(name):
		if anim.animation != name:
			anim.play(name)

func _get_anim() -> AnimatedSprite2D:
	# Preferred: child named "Anim"
	var n: Node = get_node_or_null("Anim")
	if n is AnimatedSprite2D:
		return n as AnimatedSprite2D

	# Otherwise: find first AnimatedSprite2D anywhere under this player
	return _find_anim_recursive(self)

func _find_anim_recursive(node: Node) -> AnimatedSprite2D:
	for c in node.get_children():
		if c is AnimatedSprite2D:
			return c as AnimatedSprite2D
		var found: AnimatedSprite2D = _find_anim_recursive(c)
		if found != null:
			return found
	return null
