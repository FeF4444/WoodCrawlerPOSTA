extends Node3D

@onready var animation_player: AnimationPlayer = $SpotLight3D/AnimationPlayer
@onready var audio_player: AudioStreamPlayer = $SpotLight3D/AnimationPlayer/AudioStreamPlayer

var reproducir_luz_al_entrar: bool = true

func _ready() -> void:
	if reproducir_luz_al_entrar:
		animation_player.play("la luz")
	else:
		# 1. Buscamos en qué número de pista (track) está el audio dentro de la animación
		var anim: Animation = animation_player.get_animation("la luz")
		var track_de_audio: int = -1
		
		# Recorremos las pistas para encontrar la que controla al AudioStreamPlayer
		for i in anim.get_track_count():
			if anim.track_get_path(i).get_subname(0) == "AudioStreamPlayer" or anim.track_get_type(i) == Animation.TYPE_AUDIO:
				track_de_audio = i
				break
		
		# 2. Si encontramos la pista de audio, la desactivamos temporalmente
		if track_de_audio != -1:
			anim.track_set_enabled(track_de_audio, false)
		
		# 3. Reproducemos y adelantamos la animación al final (ahora visualmente cambiará, pero el audio no se enterará)
		animation_player.play("la luz")
		animation_player.advance(animation_player.current_animation_length)
		
		# 4. Volvemos a activar la pista de audio para que funcione normalmente en el futuro
		if track_de_audio != -1:
			anim.track_set_enabled(track_de_audio, true)
			
		# Por si acaso el nodo de audio se hubiera quedado reproduciendo de fondo, lo detenemos manualmente
		if audio_player.playing:
			audio_player.stop()
