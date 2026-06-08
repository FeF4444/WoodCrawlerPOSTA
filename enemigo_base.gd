extends CharacterBody3D
class_name EnemigoBase

# --- VARIABLES COMPARTIDAS POR TODOS LOS ENEMIGOS ---
@export_group("Estadísticas Base")
@export var vida_maxima: float = 10.0
@export var vida_actual: float = 10.0
@export var velocidad_movimiento: float = 2.0
@export var rango_deteccion: float = 5.0
@export var rango_ataque: float = 1.5
@export var daño_ataque: float = 1.0

@export_group("Físicas Genéricas")
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var fuerza_empuje_externo: Vector3 = Vector3.ZERO
var friccion_empuje: float = 30.0 

# Referencia común al jugador
var jugador: CharacterBody3D = null
var esta_muerto: bool = false # Una bandera simple y universal para la base

func _ready() -> void:
	add_to_group("enemigos")
	vida_actual = vida_maxima # Aseguramos que empiece lleno
	
	# Búsqueda automática del jugador en el grupo
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.size() > 0:
		jugador = jugadores[0] as CharacterBody3D
		_on_jugador_encontrado()
	
	# Callback opcional por si los hijos necesitan inicializar algo más
	if has_method("configurar_componentes"):
		call("configurar_componentes")

func _on_jugador_encontrado() -> void:
	pass 

## Manejo universal del Knockback
func aplicar_empuje(vector_fuerza: Vector3) -> void:
	if esta_muerto: return 
	
	# Evitamos empujar al esqueleto si está colgado usando strings directos del estado del hijo
	if "modo_actual" in self and str(get("modo_actual")) == "COLGADO": return 
	
	fuerza_empuje_externo = vector_fuerza

## Procesamiento unificado de daño
func recibir_daño(cantidad: float) -> void:
	if esta_muerto: return
	
	vida_actual -= cantidad
	print("💥 ", name, " recibió ", cantidad, " de daño. Vida restante: ", vida_actual)
	
	# Avisamos al hijo que recibió daño (para que cambie de estado o ruede)
	if has_method("al_recibir_daño"):
		call("al_recibir_daño", cantidad)
		
	if vida_actual <= 0.0:
		morir()

func morir() -> void:
	if esta_muerto: return
	esta_muerto = true
	set_physics_process(false)
	
	# Si el hijo sabe cómo morir (reproducir animación, etc), que lo haga él
	if has_method("al_morir"):
		call("al_morir")
	else:
		queue_free()
