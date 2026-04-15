extends Node2D

# Game Settings
const PADDLE_SPEED = 600.0
const BALL_START_SPEED = 300.0
var ball_velocity = Vector2(BALL_START_SPEED, -BALL_START_SPEED)
var score = 0
var best_score = 0
var can_shrink = true 

# Node References
var player: CharacterBody2D
var ball: CharacterBody2D
var ball_mesh: MeshInstance2D
var score_label: Label
var boop_player: AudioStreamPlayer
var buzz_player: AudioStreamPlayer

func _ready():
	DisplayServer.window_set_title("Pong")
	setup_inputs()
	setup_audio()
	setup_world()
	reset_ball()

func setup_inputs():
	for action in ["left", "right", "toggle_shrink"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	
	InputMap.action_add_event("left", create_key_event(KEY_A))
	InputMap.action_add_event("left", create_key_event(KEY_LEFT))
	InputMap.action_add_event("right", create_key_event(KEY_D))
	InputMap.action_add_event("right", create_key_event(KEY_RIGHT))
	InputMap.action_add_event("toggle_shrink", create_key_event(KEY_C))

func create_key_event(code):
	var ev = InputEventKey.new()
	ev.keycode = code
	return ev

func setup_audio():
	# Fix: Manually populating the byte array to avoid the multiplication error
	
	# 1. Boop Sound (High pitched blip)
	boop_player = AudioStreamPlayer.new()
	var boop_stream = AudioStreamWAV.new()
	var boop_data = PackedByteArray()
	for i in range(400):
		boop_data.append(127 if i % 2 == 0 else -127)
	boop_stream.data = boop_data
	boop_stream.format = AudioStreamWAV.FORMAT_8_BITS
	boop_player.stream = boop_stream
	add_child(boop_player)

	# 2. Buzzer Sound (Low grumble)
	buzz_player = AudioStreamPlayer.new()
	var buzz_stream = AudioStreamWAV.new()
	var buzz_data = PackedByteArray()
	for i in range(4000):
		buzz_data.append(randi_range(-120, 120)) # White noise buzzer
	buzz_stream.data = buzz_data
	buzz_stream.format = AudioStreamWAV.FORMAT_8_BITS
	buzz_player.stream = buzz_stream
	add_child(buzz_player)

func setup_world():
	var bg = ColorRect.new()
	bg.color = Color.CORNFLOWER_BLUE 
	bg.set_deferred("size", Vector2(2500, 2500))
	bg.position = Vector2(-500, -500)
	add_child(bg)

	player = CharacterBody2D.new()
	player.position = Vector2(576, 600)
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING 
	add_child(player)
	
	var p_mesh = ColorRect.new()
	p_mesh.size = Vector2(120, 20)
	p_mesh.position = Vector2(-60, -10)
	player.add_child(p_mesh)
	
	var p_coll = CollisionShape2D.new()
	p_coll.shape = RectangleShape2D.new()
	p_coll.shape.size = Vector2(120, 20)
	player.add_child(p_coll)

	ball = CharacterBody2D.new()
	add_child(ball)
	
	ball_mesh = MeshInstance2D.new()
	ball_mesh.mesh = SphereMesh.new()
	ball_mesh.mesh.radius = 12
	ball_mesh.mesh.height = 24
	ball.add_child(ball_mesh)
	
	var b_coll = CollisionShape2D.new()
	b_coll.shape = CircleShape2D.new()
	b_coll.shape.radius = 12
	ball.add_child(b_coll)

	score_label = Label.new()
	score_label.position = Vector2(20, 20)
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Comic Sans MS", "Comic Sans"])
	score_label.add_theme_font_override("font", font)
	score_label.add_theme_font_size_override("font_size", 18)
	add_child(score_label)
	update_ui()

func _physics_process(delta):
	if Input.is_action_just_pressed("toggle_shrink"):
		can_shrink = !can_shrink
		if not can_shrink:
			ball.scale = Vector2(1, 1)
		update_ui()

	var dir = Input.get_axis("left", "right")
	player.velocity = Vector2(dir * PADDLE_SPEED, 0)
	player.move_and_slide()
	player.position.y = 600 
	player.position.x = clamp(player.position.x, 60, get_viewport_rect().size.x - 60)

	var collision = ball.move_and_collide(ball_velocity * delta)
	if collision:
		ball_velocity = ball_velocity.bounce(collision.get_normal())
		ball_velocity *= 1.03
		boop_player.play()
		ball_mesh.modulate = Color(randf(), randf(), randf())
		
		if collision.get_collider() == player:
			score += 1
			if score > best_score: best_score = score
			if can_shrink and score % 10 == 0 and score > 0:
				ball.scale -= Vector2(0.1, 0.1)
				if ball.scale.x < 0.2: ball.scale = Vector2(0.2, 0.2)
			update_ui()

	var v_size = get_viewport_rect().size
	if ball.position.x < 12 or ball.position.x > v_size.x - 12:
		ball_velocity.x *= -1
		boop_player.play()
	if ball.position.y < 12:
		ball_velocity.y *= -1
		boop_player.play()
		
	if ball.position.y > v_size.y:
		buzz_player.play()
		game_over()

func update_ui():
	score_label.text = "Score: %d | Best: %d\nShrink Mode: %s (Press C to toggle)" % [score, best_score, "ON" if can_shrink else "OFF"]

func reset_ball():
	var v_size = get_viewport_rect().size
	ball.position = Vector2(v_size.x / 2, v_size.y / 3)
	ball_velocity = Vector2(BALL_START_SPEED, BALL_START_SPEED)
	ball.scale = Vector2(1, 1)

func game_over():
	score = 0
	update_ui()
	reset_ball()
