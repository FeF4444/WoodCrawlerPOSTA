extends Area3D

var direccion_vuelo: Vector3 = Vector3.ZERO
var velocidad_vuelo: float = 0.0

func inicializar(dir: Vector3, vel: float) -> void:
	direccion_vuelo = dir.normalized()
	velocidad_vuelo = vel
	
	# Opcional: Hace que el nodo físico mire hacia su dirección de vuelo
	if direccion_vuelo.length() > 0.1:
		look_at(global_position + direccion_vuelo, Vector3.UP)

func _physics_process(delta: float) -> void:
	if direccion_vuelo == Vector3.ZERO: return
	
	# Desplazamiento lineal constante frame por frame
	global_position += direccion_vuelo * velocidad_vuelo * delta

func _on_body_entered(body: Node3D) -> void:
	# FILTRO CRUCIAL: Si choca contra el arbusto que la creó, se ignora por completo
	if body.is_in_group("enemigo") or "arbusto" in body.name.to_lower(): 
		return
		
	# Si impacta al jugador, le resta vida y el proyectil se elimina
	if body.is_in_group("jugador"):
		if body.has_method("recibir_daño"):
			body.recibir_daño(10.0)
			print("🎯 ¡El proyectil impactó con éxito al Jugador!")
		queue_free()
		return

	# Si impacta con el mapeado (paredes, obstáculos estáticos, etc)
	if body is StaticBody3D or body is CSGShape3D:
		print("🧱 El proyectil se destruyó contra la estructura: ", body.name)
		queue_free()
