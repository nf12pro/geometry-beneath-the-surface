extends CharacterBody2D

@export var speed: float = 220.0
@export var jump_velocity: float = 420.0
@export var gravity: float = 1200.0

# Collision layers (bit index: layer 1 = 0, layer 2 = 1)
@export var solid_layer_bit: int = 0 # SolidMap collision layer = 1
@export var air_layer_bit: int = 1   # AirMap collision layer = 2

@onready var sprite: AnimatedSprite2D = $"Sprite"

var inverted: bool = false
var invert_cooldown: float = 0.0
const INVERT_COOLDOWN_TIME: float = 0.15

func _ready() -> void:
	_apply_mode()

func _physics_process(delta: float) -> void:
	if invert_cooldown > 0.0:
		invert_cooldown -= delta

	# Invert only when supported (prevents midair flips)
	if Input.is_action_just_pressed("invert") and is_on_floor() and invert_cooldown <= 0.0:
		inverted = not inverted
		invert_cooldown = INVERT_COOLDOWN_TIME
		_apply_mode()
		velocity = Vector2.ZERO
		_snap_after_invert()

	# Move
	var dir: float = Input.get_axis("move_left", "move_right")
	velocity.x = dir * speed

	# Gravity flips
	var gdir: float = (-1.0 if inverted else 1.0)
	velocity.y += gravity * gdir * delta

	# Jump (bind jump to W/Up or another key)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_velocity * gdir

	move_and_slide()
	_update_anim(dir)

func _apply_mode() -> void:
	# Floor logic flips (critical)
	up_direction = Vector2.DOWN if inverted else Vector2.UP

	# Flip sprite upside down
	sprite.rotation = PI if inverted else 0.0

	# FORCE color swap (works even if sprite modulate is ignored)
	var c := Color.WHITE if inverted else Color.BLACK
	sprite.modulate = c
	self.modulate = c

	# Swap collision targets
	collision_mask = (1 << air_layer_bit) if inverted else (1 << solid_layer_bit)

func _snap_after_invert() -> void:
	# You requested: when inverted, TP a little DOWN to the ground.
	# So we snap DOWN when inverted, UP when normal.
	var snap_dir: Vector2 = Vector2.DOWN if inverted else Vector2.UP

	# Step 1: small push in snap direction so we don't sit on the boundary
	global_position += snap_dir * 10.0

	# Step 2: raycast to find the nearest surface in that direction
	var space := get_world_2d().direct_space_state
	var from := global_position
	var to := from + snap_dir * 600.0

	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.collision_mask = collision_mask
	q.exclude = [self]

	var hit := space.intersect_ray(q)
	if hit:
		# place just before the surface
		global_position = hit.position - snap_dir * 2.0
	else:
		# fallback: if nothing hit, try the opposite direction
		var opp_from := global_position
		var opp_to := opp_from - snap_dir * 600.0
		var q2 := PhysicsRayQueryParameters2D.create(opp_from, opp_to)
		q2.collision_mask = collision_mask
		q2.exclude = [self]
		var hit2 := space.intersect_ray(q2)
		if hit2:
			global_position = hit2.position + snap_dir * 2.0

func _update_anim(dir: float) -> void:
	if dir != 0.0:
		sprite.flip_h = dir < 0.0

	if not is_on_floor():
		var falling: bool = ((not inverted and velocity.y > 20.0) or (inverted and velocity.y < -20.0))
		sprite.play("fall" if falling else "jump")
	else:
		sprite.play("run" if absf(velocity.x) > 5.0 else "idle")
