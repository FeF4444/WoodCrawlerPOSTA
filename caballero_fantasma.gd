extends CharacterBody3D

# 🔥 NUEVA SEÑAL: Avisa al mundo para cerrar las puertas de inmediato
signal revelado

@export_category("Estadísticas Base")
@export var velocidad_persecucion: float = 3.5 
@export var vida: float = 30.0
@export var velocidad_huida: float = 4.5        
@export var distancia_deteccion: float = 12.0
@export var distancia_ataque: float = 2.5

# Fuerza del mini-desplazamiento al dar el espadazo hacia el jugador
@export var fuerza_embestida_ataque: float = 8.0

@export_category("Tiempos de Mecánica")
@export var tiempo_vulnerable_post_ataque: float = 1.0
@export var tiempo_espera_etereo: float = 2.5

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var proyector: Sprite3D = $ProyectorCaballero

enum Estados { ETEREO_PERSEGUIR, SOLIDO_ATACAR, SOLIDO_RECUPERACION, ETEREO_HUIDA, MUERTO }
var estado_actual: Estados = Estados.ETEREO_PERSEGUIR

var jugador: CharacterBody3D = null
var cronometro_etereo: float = 0.0
var cronometro_vulnerable: float = 0.0
var direccion_huida: Vector3 = Vector3.ZERO
var es_invulnerable: bool = true 

# Guarda el vector de dirección calculado al inicio del espadazo
var direccion_embestida: Vector3 = Vector3.ZERO

# Variable para controlar la fricción cuando el cañón lo empuja
var velocidad_empuje: Vector3 = Vector3.ZERO

func _ready() -> void:
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.size() > 0:
		jugador = jugadores[0]
		
	cambiar_estado(Estados.ETEREO_PERSEGUIR)
	
	# 🔥 Como este enemigo es agresivo desde el inicio, gatilla el cierre de puertas de inmediato
	revelado.emit()

func _physics_process(delta: float) -> void:
	if estado_actual == Estados.MUERTO or jugador == null: return
	
	if not is_on_floor(): velocity += get_gravity() * delta
	else: velocity.y = 0.0
		
	var distancia = global_position.distance_to(jugador.global_position)

	# Reducir gradualmente la fuerza del empuje (fricción) si fue golpeado por el cañón
	velocidad_empuje = velocidad_empuje.move_toward(Vector3.ZERO, 30.0 * delta)

	match estado_actual:
		Estados.ETEREO_PERSEGUIR:
			var direccion = (jugador.global_position - global_position).normalized()
			velocity.x = direccion.x * velocidad_persecucion
			velocity.z = direccion.z * velocidad_persecucion
			if proyector: 
				proyector.modulate.a = move_toward(proyector.modulate.a, 0.3, 2.0 * delta)
			if cronometro_etereo > 0.0: 
				cronometro_etereo -= delta
			if distancia <= distancia_ataque and cronometro_etereo <= 0.0:
				cambiar_estado(Estados.SOLIDO_ATACAR)
				
		Estados.SOLIDO_ATACAR:
			velocity.x = move_toward(velocity.x, direccion_embestida.x * fuerza_embestida_ataque, 10.0 * delta)
			velocity.z = move_toward(velocity.z, direccion_embestida.z * fuerza_embestida_ataque, 10.0 * delta)
			
			if not _animation_player.is_playing() or _animation_player.current_animation != "ataque":
				_on_ataque_terminado()
				
		Estados.SOLIDO_RECUPERACION:
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
			cronometro_vulnerable += delta
			if cronometro_vulnerable >= tiempo_vulnerable_post_ataque:
				cambiar_estado(Estados.ETEREO_HUIDA)
				
		Estados.ETEREO_HUIDA:
			velocity.x = direccion_huida.x * velocidad_huida
			velocity.z = direccion_huida.z * velocidad_huida
			if proyector: 
				proyector.modulate.a = move_toward(proyector.modulate.a, 0.3, 2.0 * delta)
			cronometro_etereo += delta
			if cronometro_etereo >= tiempo_espera_etereo:
				cronometro_etereo = tiempo_espera_etereo
				cambiar_estado(Estados.ETEREO_PERSEGUIR)
				
	velocity += velocidad_empuje
	
	move_and_slide()
	ajustar_flip_visual()

func cambiar_estado(nuevo_estado: Estados) -> void:
	estado_actual = nuevo_estado
	match estado_actual:
		Estados.ETEREO_PERSEGUIR:
			es_invulnerable = true
			reproducir_animacion("moverse")
			
		Estados.SOLIDO_ATACAR:
			es_invulnerable = false
			if proyector: proyector.modulate.a = 1.0
			
			if jugador:
				direccion_embestida = (jugador.global_position - global_position).normalized()
				direccion_embestida.y = 0.0
				
			reproducir_animacion("ataque")
			
		Estados.SOLIDO_RECUPERACION:
			es_invulnerable = false
			cronometro_vulnerable = 0.0
			reproducir_animacion("idle")
			
		Estados.ETEREO_HUIDA:
			es_invulnerable = true
			cronometro_etereo = 0.0
			reproducir_animacion("idle")
			var dir_al_jugador = (jugador.global_position - global_position).normalized()
			direccion_huida = -dir_al_jugador
			direccion_huida.y = 0.0
			
		Estados.MUERTO:
			es_invulnerable = true
			velocity = Vector3.ZERO 
			velocidad_empuje = Vector3.ZERO
			
			for hijo in get_children():
				if hijo is CollisionShape3D:
					hijo.set_deferred("disabled", true)
			
			var hitbox_malandra = find_child("HitboxAtaque", true, false)
			if hitbox_malandra:
				for col in hitbox_malandra.get_children():
					if col is CollisionShape3D: col.set_deferred("disabled", true)
					
			reproducir_animacion("muerte")
			
			await get_tree().create_timer(1.2).timeout
			print("💀 [SISTEMA]: Caballero Fantasma purgado de la memoria con éxito.")
			queue_free()

func reproducir_animacion(nombre_anim: String) -> void:
	if _animation_player and _animation_player.has_animation(nombre_anim):
		if _animation_player.current_animation != nombre_anim:
			_animation_player.play(nombre_anim)

func ajustar_flip_visual() -> void:
	if jugador == null or proyector == null: return
	var direccion_al_jugador = jugador.global_position - global_position
	var es_izquierda = transform.basis.z.cross(direccion_al_jugador).y > 0
	proyector.flip_h = es_izquierda

func recibir_daño(cantidad: float, es_ataque_pesado: bool = false) -> void:
	if es_invulnerable and not es_ataque_pesado:
		print("🛡️ ¡El caballero es etéreo! El ataque lo atraviesa.")
		return
		
	if es_invulnerable and es_ataque_pesado:
		print("🔮 ¡El Cañón es demasiado fuerte! Rompe el estado etéreo del fantasma.")
		cambiar_estado(Estados.SOLIDO_RECUPERACION) 
		
	vida -= cantidad
	print("💥 ¡IMPACTO! Vida restante del enemigo: ", vida)
	if vida <= 0.0:
		cambiar_estado(Estados.MUERTO)

func aplicar_empuje(fuerza_vector: Vector3) -> void:
	if estado_actual == Estados.MUERTO: return
	velocidad_empuje = fuerza_vector

func _on_ataque_terminado() -> void:
	if estado_actual == Estados.SOLIDO_ATACAR:
		cambiar_estado(Estados.SOLIDO_RECUPERACION)

func _on_hitbox_ataque_body_entered(body: Node3D) -> void:
	if estado_actual == Estados.ETEREO_HUIDA or estado_actual == Estados.MUERTO: return
	if body.has_method("recibir_daño") and body == jugador:
		body.recibir_daño(15.0)
		print("⚔️ ¡Machetazo del Caballero! -15 de Vida al jugador.")
