extends Camera3D

@export var objetivo_ruta: NodePath = NodePath("../Jugador")
@export var suavizado: float = 5.0
@export var desfase: Vector3 = Vector3(0.0, 10.0, 8.0)

var jugador_nodo: Node3D = null

func _ready() -> void:
	if has_node(objetivo_ruta):
		jugador_nodo = get_node(objetivo_ruta) as Node3D
	else:
		print("¡Error de Director! La cámara no encuentra al Jugador en el escenario.")

func _process(delta: float) -> void:
	if not jugador_nodo:
		return
		
	var posicion_objetivo = jugador_nodo.global_position + desfase
	global_position = global_position.lerp(posicion_objetivo, suavizado * delta)
