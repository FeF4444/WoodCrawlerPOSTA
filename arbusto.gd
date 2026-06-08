extends CharacterBody3D

signal revelado

@export_category("Rangos y Detección")
@export var rango_alerta: float = 5.0      
@export var rango_ataque: float = 1.8      
@export var rango_olvido: float = 10.0

@export_category("Estadísticas de Combate")
@export var vida: float = 20.0
@export var velocidad_persecucion: float = 2.5
@export var daño_ataque: float = 10.0

@export_category("Ajustes de Ataque Cuerpo a Cuerpo")
@export var duracion_ataque: float = 0.4 
@export var fuerza_embestida: float = 7.0 

@export_category("Ajustes de Ataque Distancia")
@export var escena_proyectil: PackedScene 
@export var cadencia_disparo: float = 1.8 
@export var velocidad_proyectil: float = 12.0
@export var duracion_animacion_disparo: float = 0.5 

@export_category("Drop Especial")
@export var id_item_drop: String = "anillo_pacto"
# Configurado por defecto al 3% (0.03). Puedes ajustarlo en el inspector entre 0.02 y 0.05
@export_range(0.0, 1.0) var probabilidad_anillo_pacto: float = 0.03
var escena_item_comprable: PackedScene = preload("res://item_comprable.tscn")

@onready var sprite_animado: AnimatedSprite3D = $MeshInstance3D/AnimatedSprite3D
@onready var hitbox_ataque: Area3D = $HitboxAtaque 
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var spotlight_ojos: SpotLight3D = find_child("SpotLight3D", true, false) as SpotLight3D

# Referencia al nuevo Marker3D
@onready var punto_spawn_drop: Marker3D = $PuntoSpawnDrop

enum Estados { OCULTO, REVELARSE, PERSEGUIR, ATACAR, DISPARAR, STUN, MUERTO }
var estado_actual: Estados = Estados.OCULTO

var jugador: CharacterBody3D = null
var cronometro_estado: float = 0.0
var cronometro_ataque: float = 0.0 
var direccion_embestida: Vector3 = Vector3.ZERO 

var puede_disparar: bool = true
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Variables de físicas de impacto y aturdimiento externos
var fuerza_empuje_externo: Vector3 = Vector3.ZERO
var cronometro_stun: float = 0.0

# --- SISTEMA DE CONTROL DE TURNOS (COMPARTIDO) ---
static var atacante_melee_actual: CharacterBody3D = null

static func solicitar_turno_ataque(enemigo: CharacterBody3D) -> bool:
	if not is_instance_valid(atacante_melee_actual) or atacante_melee_actual.estado_actual == Estados.MUERTO:
		atacante_melee_actual = null
	
	if atacante_melee_actual == null or atacante_melee_actual == enemigo:
		atacante_melee_actual = enemigo
		return true
		
	return false 

static func liberar_turno_ataque(enemigo: CharacterBody3D) -> void:
	if atacante_melee_actual == enemigo:
		atacante_melee_actual = null
# --------------------------------------------------

func _ready() -> void:
	add_to_group("enemigos")
	
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.size() > 0:
		jugador = jugadores[0]
		print("✅ Jugador encontrado y asignado con éxito.")
	else:
		print("❌ ERROR: No se encontró ningún nodo en el grupo 'jugador'.")
		
	if hitbox_ataque:
		hitbox_ataque.monitoring = false 
		
	if spotlight_ojos:
		spotlight_ojos.visible = false 
		
	cambiar_estado(Estados.OCULTO)

func _physics_process(delta: float) -> void:
	if estado_actual == Estados.MUERTO: return
	
	if not is_on_floor():
		velocity.y -= gravedad * delta
	else:
		velocity.y = 0.0
	
	fuerza_empuje_externo.x = move_toward(fuerza_empuje_externo.x, 0.0, 30.0 * delta)
	fuerza_empuje_externo.z = move_toward(fuerza_empuje_externo.z, 0.0, 30.0 * delta)
	
	if jugador == null:
		var jugadores = get_tree().get_nodes_in_group("jugador")
		if jugadores.size() > 0: jugador = jugadores[0]
		return

	if estado_actual != Estados.OCULTO and spotlight_ojos and is_instance_valid(jugador):
		var objetivo = jugador.global_position + Vector3(0, 1.2, 0)
		if global_position.distance_to(objetivo) > 0.2:
			var direccion_hacia_jugador = (objetivo - spotlight_ojos.global_position).normalized()
			if abs(direccion_hacia_jugador.dot(Vector3.UP)) < 0.99:
				spotlight_ojos.look_at(objetivo, Vector3.UP)

	var distancia = global_position.distance_to(jugador.global_position)
	var movimiento_horizontal := Vector3.ZERO

	match estado_actual:
		Estados.OCULTO:
			if distancia <= rango_alerta:
				cambiar_estado(Estados.REVELARSE)
				return

		Estados.REVELARSE:
			ajustar_flip_visual()
			cronometro_estado -= delta
			if cronometro_estado <= 0.0:
				cambiar_estado(Estados.PERSEGUIR)
				return

		Estados.PERSEGUIR:
			ajustar_flip_visual()
			
			if solicitar_turno_ataque(self):
				if distancia <= rango_ataque:
					cambiar_estado(Estados.ATACAR)
					return
				else:
					var direccion = (jugador.global_position - global_position).normalized()
					movimiento_horizontal.x = direccion.x * velocidad_persecucion
					movimiento_horizontal.z = direccion.z * velocidad_persecucion
			else:
				if puede_disparar:
					cambiar_estado(Estados.DISPARAR)
					return
				
				if distancia < 3.5:
					var dir_escape = (global_position - jugador.global_position).normalized()
					movimiento_horizontal.x = dir_escape.x * velocidad_persecucion
					movimiento_horizontal.z = dir_escape.z * velocidad_persecucion
				else:
					var dir_flanqueo = (global_position - jugador.global_position).cross(Vector3.UP).normalized()
					movimiento_horizontal = dir_flanqueo * (velocidad_persecucion * 0.5)
			
			if distancia >= rango_olvido:
				cambiar_estado(Estados.OCULTO)
				return

		Estados.ATACAR:
			movimiento_horizontal.x = direccion_embestida.x * fuerza_embestida
			movimiento_horizontal.z = direccion_embestida.z * fuerza_embestida
			
			cronometro_ataque -= delta
			if cronometro_ataque <= 0.0:
				cambiar_estado(Estados.PERSEGUIR)
				return

		Estados.DISPARAR:
			movimiento_horizontal = Vector3.ZERO
			ajustar_flip_visual()
			
			cronometro_estado -= delta
			if cronometro_estado <= 0.0:
				cambiar_estado(Estados.PERSEGUIR)
				return

		Estados.STUN:
			movimiento_horizontal = Vector3.ZERO
			cronometro_stun -= delta
			if cronometro_stun <= 0.0:
				cambiar_estado(Estados.PERSEGUIR)
				return

	velocity.x = movimiento_horizontal.x + fuerza_empuje_externo.x
	velocity.z = movimiento_horizontal.z + fuerza_empuje_externo.z
	
	move_and_slide()

func cambiar_estado(nuevo_estado: Estados) -> void:
	if nuevo_estado in [Estados.STUN, Estados.MUERTO, Estados.OCULTO]:
		liberar_turno_ataque(self)

	if estado_actual == Estados.ATACAR:
		if hitbox_ataque:
			hitbox_ataque.set_deferred("monitoring", false)

	estado_actual = nuevo_estado
	
	match estado_actual:
		Estados.OCULTO:
			velocity = Vector3.ZERO
			reproducir_animacion("quieto")
			if spotlight_ojos: spotlight_ojos.visible = false
			print("🌿 Estado cambiado: OCULTO")
			
		Estados.REVELARSE:
			cronometro_estado = 1.0 
			if spotlight_ojos: spotlight_ojos.visible = true
			reproducir_animacion("alerta")
			reproducir_ojitos_void()
			print("👀 Estado cambiado: REVELARSE")
			revelado.emit()
			
		Estados.PERSEGUIR:
			if sprite_animado: sprite_animado.speed_scale = 1.0 
			reproducir_animacion("caminando")
			reproducir_rebote(1.0) 
			print("🏃‍♂️ Estado cambiado: PERSEGUIR")
			
		Estados.ATACAR:
			cronometro_ataque = duracion_ataque
			if jugador:
				var pos_objetivo = Vector3(jugador.global_position.x, global_position.y, jugador.global_position.z)
				direccion_embestida = (pos_objetivo - global_position).normalized()
			
			if hitbox_ataque:
				hitbox_ataque.set_deferred("monitoring", true)
				await get_tree().physics_frame
				chequear_daño_inmediato()
			
			if sprite_animado: sprite_animado.speed_scale = 2.0 
			reproducir_animacion("caminando")
			reproducir_rebote(2.0) 
			print("💥 Estado cambiado: ATACAR")
			
		Estados.DISPARAR:
			cronometro_estado = duracion_animacion_disparo
			reproducir_animacion("alerta") 
			ejecutar_disparo()

		Estados.STUN:
			detener_rebote()
			reproducir_animacion("alerta")
			print("😵 Enemigo ATURDIDO por el jugador.")

		Estados.MUERTO:
			velocity = Vector3.ZERO
			liberar_turno_ataque(self) 
			if sprite_animado: sprite_animado.speed_scale = 1.0
			if hitbox_ataque: hitbox_ataque.set_deferred("monitoring", false)
			if spotlight_ojos: spotlight_ojos.visible = false
			
			# OBTENER LA POSICIÓN DEL MARKER3D EN EL MUNDO ABSOLUTO
			var posicion_muerte: Vector3 = global_position
			if is_instance_valid(punto_spawn_drop):
				posicion_muerte = punto_spawn_drop.global_position
			else:
				posicion_muerte = self.global_transform.origin
				posicion_muerte.y = 0.5
			
			if escena_item_comprable and jugador:
				if jugador.ITEMS_DB.has(id_item_drop):
					# Evaluar probabilidad usando randf() (devuelve entre 0.0 y 1.0)
					if randf() <= probabilidad_anillo_pacto:
						var item_drop = escena_item_comprable.instantiate()
						
						if "posicion_forzada" in item_drop:
							item_drop.posicion_forzada = posicion_muerte
						
						var datos_item = jugador.ITEMS_DB[id_item_drop]
						if item_drop.has_method("configurar_articulo"):
							item_drop.configurar_articulo(id_item_drop, datos_item, 0)
						
						get_tree().root.add_child(item_drop)
						item_drop.global_position = posicion_muerte
						
						print("💍 ¡Suerte! Drop generado mediante Marker3D en!: ", posicion_muerte)
					else:
						print("🎲 Probabilidad fallida. El enemigo no soltó el drop.")
				else:
					print("❌ ERROR: El ID de ítem '" + id_item_drop + "' no existe en ITEMS_DB.")

			for hijo in get_children():
				if hijo is CollisionShape3D: hijo.set_deferred("disabled", true)
				
			if animation_player and animation_player.has_animation("muerte"):
				animation_player.speed_scale = 1.0
				animation_player.play("muerte")
				if not animation_player.animation_finished.is_connected(_on_muerte_animacion_terminada):
					animation_player.animation_finished.connect(_on_muerte_animacion_terminada)
			else:
				queue_free()

func recibir_stun(tiempo: float) -> void:
	if estado_actual == Estados.MUERTO: return
	cronometro_stun = tiempo
	cambiar_estado(Estados.STUN)

func aplicar_empuje(vector_fuerza: Vector3) -> void:
	if estado_actual == Estados.MUERTO: return
	fuerza_empuje_externo = vector_fuerza

func ejecutar_disparo() -> void:
	if not escena_proyectil or jugador == null: return
	puede_disparar = false
	
	var proyectil = escena_proyectil.instantiate() as Node3D
	get_tree().root.add_child(proyectil)
	
	proyectil.global_position = global_position + Vector3(0, 1.0, 0)
	
	var pos_jugador_plana = Vector3(jugador.global_position.x, proyectil.global_position.y, jugador.global_position.z)
	var direccion = (pos_jugador_plana - proyectil.global_position).normalized()
	
	if proyectil.has_method("inicializar"):
		proyectil.inicializar(direccion, velocidad_proyectil)
		
	get_tree().create_timer(cadencia_disparo).timeout.connect(func(): puede_disparar = true)

func reproducir_animacion(nombre_anim: String) -> void:
	if sprite_animado and sprite_animado.sprite_frames.has_animation(nombre_anim):
		sprite_animado.play(nombre_anim)

func reproducir_ojitos_void() -> void:
	if animation_player and animation_player.has_animation("ojitos void"):
		animation_player.play("ojitos void")

func reproducir_rebote(velocidad: float) -> void:
	if animation_player and animation_player.has_animation("bounce"):
		if animation_player.current_animation in ["muerte", "ojitos void"]: return
		animation_player.speed_scale = velocidad
		if animation_player.current_animation != "bounce":
			animation_player.play("bounce")

func detener_rebote() -> void:
	if animation_player:
		if animation_player.current_animation in ["muerte", "ojitos void"]: return
		if animation_player.has_animation("RESET"):
			animation_player.play("RESET") 
		else:
			animation_player.stop()

func ajustar_flip_visual() -> void:
	if jugador == null or sprite_animado == null: return
	var direccion_x = jugador.global_position.x - global_position.x
	if abs(direccion_x) > 0.05:
		sprite_animado.flip_h = direccion_x < 0

func recibir_daño(cantidad: float) -> void:
	if estado_actual == Estados.MUERTO: return
	if estado_actual == Estados.OCULTO:
		cambiar_estado(Estados.REVELARSE)
		
	vida -= cantidad
	if vida <= 0.0:
		cambiar_estado(Estados.MUERTO)

func chequear_daño_inmediato() -> void:
	if estado_actual != Estados.ATACAR or hitbox_ataque == null or not hitbox_ataque.monitoring: return
	for cuerpo in hitbox_ataque.get_overlapping_bodies():
		if cuerpo == jugador:
			aplicar_daño_al_jugador(cuerpo)
			break

func aplicar_daño_al_jugador(body: Node3D) -> void:
	if body.has_method("recibir_daño"):
		body.recibir_daño(daño_ataque) 
		if hitbox_ataque: hitbox_ataque.set_deferred("monitoring", false)

func _on_hitbox_ataque_body_entered(body: Node3D) -> void:
	if estado_actual == Estados.ATACAR and body == jugador:
		aplicar_daño_al_jugador(body)

func _on_muerte_animacion_terminada(anim_name: String) -> void:
	if anim_name == "muerte":
		queue_free()
