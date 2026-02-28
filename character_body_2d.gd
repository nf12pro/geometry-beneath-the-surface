extends CharacterBody2D

@export var speed: float = 220.0
@export var jump_velocity: float = 420.0
@export var gravity: float = 1200.0
@export var solid_layer_bit: int = 0
@export var air_layer_bit: int = 1

@onready var sprite: AnimatedSprite2D = $"Sprite"

var inverted: bool = false
var invert_cooldown: float = 0.0
const INVERT_COOLDOWN_TIME: float = 0.15

func _ready() -> void:
	_apply_mode()

func _physics_process(delta: float) -> void:
	# FIX 6: decrement cooldown only, check it separately below
	if invert_cooldown > 0.0:
		invert_cooldown -= delta

	var dir: float = Input.get_axis("move_left", "move_right")
	velocity.x = dir * speed

	var gdir: float = (-1.0 if inverted else 1.0)
	velocity.y += gravity * gdir * delta

	move_and_slide()

	# FIX 1: invert and jump checks are now AFTER move_and_slide so is_on_floor() is fresh
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_velocity * gdir

	if Input.is_action_just_pressed("invert") and is_on_floor() and invert_cooldown <= 0.0:
		inverted = not inverted
		invert_cooldown = INVERT_COOLDOWN_TIME
		_apply_mode()
		velocity = Vector2.ZERO
		_snap_after_invert()

	_update_anim(dir)

func _apply_mode() -> void:
	up_direction = Vector2.DOWN if inverted else Vector2.UP
	sprite.rotation = PI if inverted else 0.0
	# FIX 3: only set sprite.modulate, not both self and sprite
	sprite.modulate = Color.WHITE if inverted else Color.BLACK
	collision_mask = (1 << air_layer_bit) if inverted else (1 << solid_layer_bit)

func _snap_after_invert() -> void:
	var snap_dir: Vector2 = Vector2.DOWN if inverted else Vector2.UP

	# FIX 2: raycast from current position directly, no pre-nudge
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + snap_dir * 600.0)
	q.collision_mask = collision_mask
	q.exclude = [self]
	var hit := space.intersect_ray(q)

	if hit:
		global_position = hit.position - snap_dir * 2.0
	else:
		# Fallback: try opposite direction
		var q2 := PhysicsRayQueryParameters2D.create(global_position, global_position - snap_dir * 600.0)
		q2.collision_mask = collision_mask
		q2.exclude = [self]
		var hit2 := space.intersect_ray(q2)
		if hit2:
			global_position = hit2.position + snap_dir * 2.0

	# FIX 5: give a small velocity push toward new floor so gravity takes over cleanly
	velocity.y = 50.0 * gdir_current()

func gdir_current() -> float:
	return -1.0 if inverted else 1.0

func _update_anim(dir: float) -> void:
	# FIX 4: always update flip_h, not only when moving
	sprite.flip_h = dir < 0.0 if dir != 0.0 else sprite.flip_h

	if not is_on_floor():
		var falling: bool = ((not inverted and velocity.y > 20.0) or (inverted and velocity.y < -20.0))
		sprite.play("fall" if falling else "jump")
	else:
		sprite.play("run" if absf(velocity.x) > 5.0 else "idle")
