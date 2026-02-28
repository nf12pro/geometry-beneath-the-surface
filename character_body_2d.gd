extends CharacterBody2D

# --- Movement Settings ---
@export var speed: float = 240.0
@export var jump_velocity: float = 520.0 
@export var gravity: float = 1400.0

# --- Invert Settings ---
@export_flags_2d_physics var surface_layer: int = 1
@export_flags_2d_physics var underground_layer: int = 2

# This MUST be larger than your tile's height, or you will get stuck inside the block!
# If your tiles are 16x16, try setting this to 18 or 20.
@export var floor_thickness_offset: float = 20.0 

var is_underground: bool = false

@onready var anim: AnimatedSprite2D = $Anim

func _ready() -> void:
	_update_physics_state()

func _physics_process(delta: float) -> void:
	# 1. Handle Inversion (Space)
	if Input.is_action_just_pressed("invert") and is_on_floor():
		is_underground = !is_underground
		_update_physics_state()
		
		var push_dir := 1.0 if is_underground else -1.0
		
		# THE FIX: round() cleans up messy spawn decimals before we teleport!
		global_position.y = round(global_position.y) + (floor_thickness_offset * push_dir)
		
		velocity.y = 0.0

	# 2. Determine Gravity Direction
	var gravity_dir := -1.0 if is_underground else 1.0

	# 3. Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * gravity_dir * delta

	# 4. Handle Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_velocity * gravity_dir

	# 5. Handle Horizontal Movement
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * speed
		if anim: anim.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	# 6. Apply Movement
	move_and_slide()
	_update_animations()

# --- Helper Functions ---

func _update_physics_state() -> void:
	collision_mask = underground_layer if is_underground else surface_layer
	up_direction = Vector2.DOWN if is_underground else Vector2.UP
	
	if anim:
		anim.flip_v = is_underground
		anim.modulate = Color.WHITE if is_underground else Color.BLACK

func _update_animations() -> void:
	if not anim or not anim.sprite_frames: return
	
	if is_on_floor():
		if velocity.x != 0:
			anim.play("run")
		else:
			anim.play("idle")
	else:
		var is_moving_up := (velocity.y < 0) if not is_underground else (velocity.y > 0)
		if is_moving_up:
			anim.play("jump")
		else:
			anim.play("fall")
