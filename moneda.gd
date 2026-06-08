extends Area3D

@export var valor_moneda: int = 1

func _ready() -> void:
	# Asegura que las propiedades físicas esenciales estén activas por código
	monitoring = true
	monitorable = true
	
	# Conectamos la señal de que algo entró a la moneda
	body_entered.connect(_on_body_entered)
	
	# Forzado de seguridad por si el motor lee un pivot dañado en el modelo original
	await get_tree().process_frame
	if is_inside_tree():
		global_position.y = 0.6

func _on_body_entered(body: Node) -> void:
	# Verificamos si el cuerpo que entró tiene la función de añadir monedas
	if body.has_method("añadir_monedas"):
		body.añadir_monedas(valor_moneda)
		# Puedes reproducir un sonido aquí antes de borrarla
		queue_free()
