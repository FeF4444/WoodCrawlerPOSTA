extends CharacterBody3D # Mantén "extends EnemigoBase" si usas tu herencia original

@export_category("Estadísticas Base")
@export var velocidad_movimiento: float = 2.8   # Camina más fluido y amenazante
@export var velocidad_locura: float = 7.0       # El sprint desbocado global
@export var vida: float = 15.0
@export var rango_ataque_corto: float = 1.8     # Rango de mordida torpe
@export var rango_deteccion_inicial: float = 6.5 # Rango de "visión de ciego" ampliado

@export_category("Ajustes de Ataque y Agarre")
@export var fuerza_embestida_ataque: float = 6.0 # Fuerza del minidash torpe al morder
@export var duracion_paralisis_locura: float = 1.2
@export var duracion_agarre: float = 3.0
@export var daño_ataque: float = 5.0

enum ModosEsqueleto { NORMAL, PREPARANDO_LOCURA, LOCURA, COLGADO, MUERTO }
var modo_actual: ModosEsqueleto = ModosEsqueleto.NORMAL

var cronometro_modo: float = 0.0
var cronometro_mordisco_normal: float = 0.0
var ya_detectado: bool = false
var es_invulnerable: bool = false

var jugador: CharacterBody3D = null
var velocidad_empuje: Vector3 = Vector3.ZERO
var direccion_embestida_corta: Vector3 = Vector3.ZERO

@onready var sprite_animado: AnimatedSprite3D = $MeshInstance3D/AnimatedSprite3D
@onready var hitbox_ataque: Area3D = $HitboxAtaque

func _ready() -> void:
	_set_hitbox_collision(true)
	
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.size() > 0:
		jugador = jugadores[0]

	if hitbox_ataque and not hitbox_ataque.body_entered.is_connected(_on_hitbox_ataque_body_entered):
		hitbox_ataque.body_entered.connect(_on_hitbox_ataque_body_entered)

func _physics_process(delta: float) -> void:
	if modo_actual == ModosEsqueleto.MUERTO or jugador == null: return
	
	if modo_actual != ModosEsqueleto.COLGADO:
		if not is_on_floor(): 
			velocity += get_gravity() * delta
		else: 
			velocity.y = 0.0
	else:
		# Acople total en los hombros del jugador durante el agarre
		global_position = jugador.global_position + Vector3(0.0, 0.6, 0.0)
		procesar_comportamiento_enemigo(delta)
		return

	velocidad_empuje = velocidad_empuje.move_toward(Vector3.ZERO, 30.0 * delta)
	procesar_comportamiento_enemigo(delta)

func procesar_comportamiento_enemigo(delta: float) -> void:
	var distancia = global_position.distance_to(jugador.global_position)
	
	match modo_actual:
		ModosEsqueleto.NORMAL:
			
			if distancia <= rango_ataque_corto:
				ya_detectado = true 
				
				cronometro_mordisco_normal -= delta
				if cronometro_mordisco_normal <= 0.0:
					ejecutar_mordisco_torpe()
					cronometro_mordisco_normal = 1.8
				
				velocity.x = move_toward(velocity.x, direccion_embestida_corta.x * fuerza_embestida_ataque, 12.0 * delta)
				velocity.z = move_toward(velocity.z, direccion_embestida_corta.z * fuerza_embestida_ataque, 12.0 * delta)
			
			else:
				if ya_detectado and distancia > rango_ataque_corto:
					cambiar_modo_esqueleto(ModosEsqueleto.PREPARANDO_LOCURA)
					return
				
				if distancia <= rango_deteccion_inicial:
					var direccion = (jugador.global_position - global_position).normalized()
					velocity.x = direccion.x * velocidad_movimiento
					velocity.z = direccion.z * velocidad_movimiento
					_reproducir_animacion("caminando")
					_ajustar_flip_visual()
				else:
					velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
					velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
					_reproducir_animacion("idle")
			
			velocity += velocidad_empuje
			move_and_slide()

		ModosEsqueleto.PREPARANDO_LOCURA:
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
			velocity += velocidad_empuje
			move_and_slide()
			
			cronometro_modo -= delta
			if cronometro_modo <= 0.0:
				cambiar_modo_esqueleto(ModosEsqueleto.LOCURA)

		ModosEsqueleto.LOCURA:
			var direccion = (jugador.global_position - global_position).normalized()
			velocity.x = direccion.x * velocidad_locura
			velocity.z = direccion.z * velocidad_locura
			velocity.y = 0.0
			
			velocity += velocidad_empuje
			var colisiono = move_and_slide()
			_ajustar_flip_visual()
			_reproducir_animacion("corriendo")
			
			var golpeo_jugador = false
			if colisiono:
				for i in get_slide_collision_count():
					var col = get_slide_collision(i)
					if col.get_collider() == jugador:
						golpeo_jugador = true
						break

			if distancia <= rango_ataque_corto or golpeo_jugador:
				cambiar_modo_esqueleto(ModosEsqueleto.COLGADO)

		ModosEsqueleto.COLGADO:
			cronometro_modo -= delta
			if int(cronometro_modo * 10) % 10 == 0: 
				_activar_hitbox_instantanea()
				
			if cronometro_modo <= 0.0:
				_soltar_jugador()
				cambiar_modo_esqueleto(ModosEsqueleto.NORMAL)

func cambiar_modo_esqueleto(nuevo_modo: ModosEsqueleto) -> void:
	modo_actual = nuevo_modo
	
	match modo_actual:
		ModosEsqueleto.PREPARANDO_LOCURA:
			cronometro_modo = duracion_paralisis_locura
			direccion_embestida_corta = Vector3.ZERO
			_reproducir_animacion("alerta")

		ModosEsqueleto.LOCURA:
			print("🤬 ¡Corriendo a por ti de forma global!")

		ModosEsqueleto.COLGADO:
			cronometro_modo = duracion_agarre
			_reproducir_animacion("salto") 
			set_collision_mask_value(1, false)
				
			if is_instance_valid(jugador):
				if "puede_dashear" in jugador:
					jugador.puede_dashear = false
				# 🛠️ NUEVO: Invertimos los controles del jugador al colgarse
				if "controles_invertidos" in jugador:
					jugador.controles_invertidos = true
			
			_activar_hitbox_instantanea()
			print("🩸 ¡Te ha atrapado! ¡Controles invertidos!")
			
		ModosEsqueleto.MUERTO:
			velocity = Vector3.ZERO
			velocidad_empuje = Vector3.ZERO
			for hijo in get_children():
				if hijo is CollisionShape3D:
					hijo.set_deferred("disabled", true)
			_set_hitbox_collision(true)
			_reproducir_animacion("muerte")
			
			if sprite_animado and sprite_animado.sprite_frames.has_animation("muerte"):
				if not sprite_animado.animation_finished.is_connected(queue_free):
					sprite_animado.animation_finished.connect(queue_free)
			else:
				await get_tree().create_timer(1.2).timeout
				queue_free()

func ejecutar_mordisco_torpe() -> void:
	_reproducir_animacion("mordida")
	if is_instance_valid(jugador):
		direccion_embestida_corta = (jugador.global_position - global_position).normalized()
		direccion_embestida_corta.y = 0.0
	_activar_hitbox_instantanea()

func _activar_hitbox_instantanea() -> void:
	_set_hitbox_collision(false)
	await get_tree().create_timer(0.15).timeout
	_set_hitbox_collision(true)

func _soltar_jugador() -> void:
	set_collision_mask_value(1, true)
	
	if is_instance_valid(jugador):
		if "puede_dashear" in jugador:
			jugador.puede_dashear = true
		# 🛠️ NUEVO: Devolvemos los controles a la normalidad al soltarse
		if "controles_invertidos" in jugador:
			jugador.controles_invertidos = false
		
	var dir_escape = (global_position - jugador.global_position).normalized()
	dir_escape.y = 0.3
	aplicar_empuje(dir_escape * 7.0)
	
	ya_detectado = false 
	cronometro_mordisco_normal = 0.8
	print("🦴 Suelto. Controles devueltos.")

# --- INTERACCIONES DE COMBATE ---

func _on_hitbox_ataque_body_entered(body: Node3D) -> void:
	if modo_actual == ModosEsqueleto.MUERTO: return
	if body == jugador and body.has_method("recibir_daño"):
		body.recibir_daño(daño_ataque)

func _set_hitbox_collision(desactivar: bool) -> void:
	if hitbox_ataque:
		for hijo in hitbox_ataque.get_children():
			if hijo is CollisionShape3D:
				hijo.set_deferred("disabled", desactivar)

func recibir_daño(cantidad: float, es_ataque_pesado: bool = false) -> void:
	if es_invulnerable and not es_ataque_pesado: return
	vida -= cantidad
	print("💥 ¡Impacto en el cráneo! Vida restante: ", vida)
	
	velocity = Vector3.ZERO
	direccion_embestida_corta = Vector3.ZERO
	
	if modo_actual == ModosEsqueleto.COLGADO:
		_soltar_jugador()
		cambiar_modo_esqueleto(ModosEsqueleto.NORMAL)
	elif modo_actual == ModosEsqueleto.LOCURA:
		cambiar_modo_esqueleto(ModosEsqueleto.NORMAL)
		
	if vida <= 0.0:
		cambiar_modo_esqueleto(ModosEsqueleto.MUERTO)

func aplicar_empuje(fuerza_vector: Vector3) -> void:
	if modo_actual == ModosEsqueleto.MUERTO: return
	velocidad_empuje = fuerza_vector

func recibir_stun(_tiempo: float) -> void:
	velocity = Vector3.ZERO
	direccion_embestida_corta = Vector3.ZERO
	
	if modo_actual == ModosEsqueleto.COLGADO:
		_soltar_jugador()
	cambiar_modo_esqueleto(ModosEsqueleto.NORMAL)
	_reproducir_animacion("idle")

# --- VOLTEO VISUAL CORREGIDO ---

func _reproducir_animacion(anim_nombre: String) -> void:
	if sprite_animado and sprite_animado.sprite_frames.has_animation(anim_nombre):
		sprite_animado.play(anim_nombre)

func _ajustar_flip_visual() -> void:
	if jugador == null or sprite_animado == null: return
	var direccion_x = jugador.global_position.x - global_position.x
	if abs(direccion_x) > 0.05:
		sprite_animado.flip_h = direccion_x > 0
