extends Node

@onready var player1 = $Player1
@onready var player2 = $Player2

const BPM : float = 118.0
const LOOP_OUT_TIME : float = 96.0 * (60.0 / BPM) 
const REVERB_TAIL : float = 8.0 * (60.0 / BPM) 

var current_player : AudioStreamPlayer
var next_player : AudioStreamPlayer
var loop_triggered : bool = false

func _ready():
	current_player = player1
	next_player = player2
	
	# Esperar 4 segundos antes de iniciar la música
	await get_tree().create_timer(4.0).timeout
	
	current_player.volume_db = -15
	current_player.play()

func _process(_delta):
	# Si aún no está sonando nada, no hacemos nada
	if not current_player.playing:
		return
		
	var playback_pos = current_player.get_playback_position()
	
	if playback_pos >= LOOP_OUT_TIME and not loop_triggered:
		loop_triggered = true
		trigger_loop()

func trigger_loop():
	next_player.volume_db = -15
	next_player.play(0.0) 
	
	var old_player = current_player
	
	var tween = create_tween()
	tween.tween_property(old_player, "volume_db", -80.0, REVERB_TAIL)
	tween.tween_callback(old_player.stop)
	
	current_player = next_player
	next_player = old_player
	
	loop_triggered = false
