extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_force: float = 400.0
@export var gravity: float = 800.0

var is_underground: bool = false
var gravity_dir: float = 1.0
var on_ground: bool = false

func _ready() -> void:
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)

func _physics_process(delta: float) -> void:
	velocity.y += gravity * gravity_dir * delta

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed

	if Input.is_action_just_pressed("jump") and on_ground:
		velocity.y = -jump_force * gravity_dir

	# R to reset — "the deeper you try to uncover the more the reality breaks"
	if Input.is_key_pressed(KEY_R):
		position = Vector2(0, 80)
		velocity = Vector2.ZERO
		is_underground = false
		gravity_dir = 1.0
		set_collision_mask_value(1, true)
		set_collision_mask_value(2, false)

	move_and_slide()

	on_ground = is_on_floor() if not is_underground else is_on_ceiling()

	if Input.is_action_just_pressed("ui_select") and on_ground and velocity.x == 0:
		is_underground = !is_underground
		if is_underground:
			gravity_dir = -1.0
			set_collision_mask_value(1, false)
			set_collision_mask_value(2, true)
		else:
			gravity_dir = 1.0
			set_collision_mask_value(1, true)
			set_collision_mask_value(2, false)
		velocity.y = -jump_force * gravity_dir
