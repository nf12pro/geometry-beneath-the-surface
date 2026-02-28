extends CharacterBody2D

@export var max_speed := 240.0
@export var accel := 2000.0
@export var air_accel := 1200.0
@export var friction := 2200.0
@export var gravity := 1400.0
@export var jump_speed := 520.0
@export var coyote_time := 0.10
@export var jump_buffer := 0.10
@export var fall_gravity_mult := 1.35
@export var jump_cut_mult := 0.55  # lower = shorter tap jumps

@onready var anim: AnimatedSprite2D = $Anim

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

func _physics_process(delta: float) -> void:
	# Timers
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer

	# Horizontal input
	var input_dir := Input.get_axis("move_left", "move_right")
	var target_speed := input_dir * max_speed
	var a := accel if is_on_floor() else air_accel

	if abs(input_dir) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, a * delta)
	else:
		# friction to stop precisely
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Gravity (stronger when falling for snappy feel)
	var g := gravity
	if velocity.y > 0.0:
		g *= fall_gravity_mult
	velocity.y += g * delta

	# Jump (buffer + coyote)
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = -jump_speed
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# Jump cut (tap jump = shorter)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_mult

	move_and_slide()
	_update_animation(input_dir)

func _update_animation(_input_dir: float) -> void:
	# Flip based on movement
	if abs(velocity.x) > 5.0:
		anim.flip_h = velocity.x < 0.0

	# Choose animation
	if is_on_floor():
		if abs(velocity.x) > 10.0:
			_play("run")
		else:
			_play("idle")
	else:
		if velocity.y < 0.0:
			_play("jump")
		else:
			_play("fall")

func _play(name: String) -> void:
	if anim.animation != name:
		anim.play(name)
