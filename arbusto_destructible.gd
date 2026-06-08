extends Area3D # O StaticBody3D si bloquea el paso del jugador

# Señal que avisa al Mundo que este arbusto fue roto y dónde estaba
signal destruido(posicion_global)

@export var vida: int = 1

# Función que llamará el jugador con su espada/ataque
func recibir_daño(cantidad: int) -> void:
	vida -= cantidad
	if vida <= 0:
		romper_arbusto()

func romper_arbusto() -> void:
	# Emitimos la señal pasando la posición actual antes de borrarlo
	destruido.emit(global_position)
	
	# Aquí puedes instanciar partículas de hojas o sonido si quieres
	
	queue_free()
