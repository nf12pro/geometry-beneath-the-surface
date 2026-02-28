extends CharacterBody2D

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

@onready var anim: AnimatedSprite2D = get_node_or_null("Anim")

var coyote_timer: float = 0.0
var buffer_timer: float = 0.0

func _physics_process(delta: float) -> void:
	# ---- timers ----
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	buffer_timer = maxf(0.0, buffer_timer - delta)
	if Input.is_action_just_pressed("jump"):
		buffer_timer = jump_buffer

	# ---- horizontal ----
	var input_dir: float = Input.get_axis("move_left", "move_right")
	var target_x: float = input_dir * max_speed
	var a: float = accel_ground if is_on_floor() else accel_air

	if absf(input_dir) > 0.01:
		velocity.x = move_toward(velocity.x, target_x, a * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# ---- gravity ----
	var g: float = gravity
	if velocity.y > 0.0:
		g *= fall_gravity_mult
	velocity.y += g * delta

	# ---- jump (buffer + coyote) ----
	if buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = -jump_speed
		buffer_timer = 0.0
		coyote_timer = 0.0

	# ---- jump cut ----
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_mult

	move_and_slide()

	_update_animation(input_dir)

func _update_animation(input_dir: float) -> void:
	if anim == null:
		return  # prevents crashes if node name is different

	# Face direction
	if absf(velocity.x) > 5.0:
		anim.flip_h = velocity.x < 0.0

	# Choose anim
	if is_on_floor():
		if absf(velocity.x) > 10.0:
			_play_anim("run")
		else:
			_play_anim("idle")
	else:
		if velocity.y < 0.0:
			_play_anim("jump")
		else:
			_play_anim("fall")

func _play_anim(name: String) -> void:
	if anim.animation != name:
		anim.play(name)
