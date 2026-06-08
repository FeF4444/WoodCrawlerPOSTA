extends EnemigoBase

@export_category("Estadísticas de la Rueda")
@export var velocidad_giro_rueda: float = 12.0     # Velocidad brutal al rodar
@export var daño_espadazo: float = 6.0            # Daño del ataque cuerpo a cuerpo
@export var daño_atropello: float = 4.0           # Daño por chocar rodando
@export var fuerza_empuje_atropello: float = 8.0  # Fuerza del empuje al arrollar (aumentado para impacto)
@export var tiempo_recarga_ataque: float = 1.5    # Cooldown normal
@export var tiempo_aturdido_pared: float = 2.5    # Tiempo que queda indefensa tras fallar
@export var max_rebotes: int = 2                  # Cuántas veces puede rebotar antes de cansarse

enum EstadosRueda { PATRULLA_IDLE, DETECTANDO, BUSCANDO, PREPARANDO_GIRO, RODANDO, ATURDIDO, COOLDOWN, ATACANDO_MELEE, MUERTO }
var estado_actual: EstadosRueda = EstadosRueda.PATRULLA_IDLE

var cronometro_estado: float = 0.0
var direccion_rodar: Vector3 = Vector3.ZERO
var rebotes_actuales: int = 0

@onready var sprite_animado: AnimatedSprite3D = $AnimatedSprite3D
@onready var hitbox_ataque: Area3D = $HitboxAtaque

func configurar_componentes() -> void:
	# La hitbox del Area3D SIEMPRE debe estar activa para escuchar colisiones, 
	# lo que activamos/desactivamos es el monitoreo del daño, no su existencia física.
	if hitbox_ataque:
		hitbox_ataque.monitoring = true
		hitbox_ataque.monitorable = true
		if not hitbox_ataque.body_entered.is_connected(_on_hitbox_ataque_body_entered):
			hitbox_ataque.body_entered.connect(_on_hitbox_ataque_body_entered)
	
	estado_actual = EstadosRueda.PATRULLA_IDLE
	_reproducir_animacion("idle")
	print("⚙️ [RUEDA] Configurada y lista para rodar. Vida: ", vida_actual)

func _physics_process(delta: float) -> void:
	if esta_muerto or estado_actual == EstadosRueda.MUERTO: return
	if jugador == null: return

	# Gravedad estándar
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	# Aplicar fricción al knockback que recibe el enemigo
	fuerza_empuje_externo = fuerza_empuje_externo.move_toward(Vector3.ZERO, friccion_empuje * delta)
	
	procesar_comportamiento(delta)

func procesar_comportamiento(delta: float) -> void:
	var distancia = global_position.distance_to(jugador.global_position)
	
	match estado_actual:
		
		EstadosRueda.PATRULLA_IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
			if distancia <= rango_deteccion:
				cambiar_estado(EstadosRueda.DETECTANDO)
			_aplicar_movimiento_final()

		EstadosRueda.DETECTANDO:
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
			cronometro_estado -= delta
			if cronometro_estado <= 0.0:
				cambiar_estado(EstadosRueda.BUSCANDO)
			_aplicar_movimiento_final()

		EstadosRueda.BUSCANDO:
			var direccion = (jugador.global_position - global_position).normalized()
			_ajustar_flip_visual()
			
			if distancia <= rango_ataque:
				cambiar_estado(EstadosRueda.ATACANDO_MELEE)
				return
			
			if distancia > rango_ataque * 3.5:
				cambiar_estado(EstadosRueda.PREPARANDO_GIRO)
				return
			
			velocity.x = direccion.x * velocidad_movimiento
			velocity.z = direccion.z * velocidad_movimiento
			_aplicar_movimiento_final()

		EstadosRueda.PREPARANDO_GIRO:
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
			cronometro_estado -= delta
			if cronometro_estado <= 0.0:
				cambiar_estado(EstadosRueda.RODANDO)
			_aplicar_movimiento_final()

		EstadosRueda.RODANDO:
			# Forzamos velocidad pura en la dirección elegida
			velocity.x = direccion_rodar.x * velocidad_giro_rueda
			velocity.z = direccion_rodar.z * velocidad_giro_rueda
			
			# Al rodar combinamos con fuerzas externas si las hay
			velocity += fuerza_empuje_externo
			
			var colisiono = move_and_slide()
			cronometro_estado -= delta
			
			# CÁLCULO DE REBOTES MEJORADO
			if colisiono and get_slide_collision_count() > 0:
				var col = get_slide_collision(0)
				var colider = col.get_collider()
				
				# Si choca contra una pared u objeto del entorno (no el jugador)
				if colider != jugador and colider != self:
					if rebotes_actuales < max_rebotes:
						rebotes_actuales += 1
						# Rebotar usando la normal de la colisión física
						var vector_rebote = direccion_rodar.bounce(col.get_normal()).normalized()
						direccion_rodar = vector_rebote
						direccion_rodar.y = 0.0
						print("🔄 ¡Rebote ", rebotes_actuales, "/", max_rebotes, " contra pared!")
					else:
						cambiar_estado(EstadosRueda.ATURDIDO)
						return
						
			if cronometro_estado <= 0.0:
				cambiar_estado(EstadosRueda.COOLDOWN)

		EstadosRueda.ATACANDO_MELEE:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			cronometro_estado -= delta
			if cronometro_estado <= 0.0:
				cambiar_estado(EstadosRueda.COOLDOWN)
			_aplicar_movimiento_final()

		EstadosRueda.ATURDIDO, EstadosRueda.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			cronometro_estado -= delta
			if cronometro_estado <= 0.0:
				cambiar_estado(EstadosRueda.BUSCANDO)
			_aplicar_movimiento_final()

func _aplicar_movimiento_final() -> void:
	velocity += fuerza_empuje_externo
	move_and_slide()

func cambiar_estado(nuevo_estado: EstadosRueda) -> void:
	if estado_actual == EstadosRueda.MUERTO: return
	estado_actual = nuevo_estado
	
	if sprite_animado: sprite_animado.speed_scale = 1.0

	match estado_actual:
		EstadosRueda.PATRULLA_IDLE:
			_reproducir_animacion("idle")
		EstadosRueda.DETECTANDO:
			cronometro_estado = 0.8
			_reproducir_animacion("alerta")
		EstadosRueda.BUSCANDO:
			_reproducir_animacion("moviendose")
		EstadosRueda.PREPARANDO_GIRO:
			cronometro_estado = 1.2
			rebotes_actuales = 0 
			_reproducir_animacion("moviendose_rapido_prerandose")
		EstadosRueda.RODANDO:
			cronometro_estado = 4.0 
			_reproducir_animacion("moviendose_rapido_prerandose")
			if sprite_animado: sprite_animado.speed_scale = 1.8 
			
			# Fijamos la dirección inicial del tiro apuntando al jugador
			direccion_rodar = (jugador.global_position - global_position).normalized()
			direccion_rodar.y = 0.0
		EstadosRueda.ATACANDO_MELEE:
			_reproducir_animacion("ataque_cc")
			cronometro_estado = 0.6 
		EstadosRueda.ATURDIDO:
			cronometro_estado = tiempo_aturdido_pared
			_reproducir_animacion("idle")
		EstadosRueda.COOLDOWN:
			cronometro_estado = tiempo_recarga_ataque
			_reproducir_animacion("idle")
		EstadosRueda.MUERTO:
			print("💀 [RUEDA] Eliminando nodo.")
			velocity = Vector3.ZERO
			set_physics_process(false)
			
			# Desactivar colisiones físicas de inmediato
			for hijo in get_children():
				if hijo is CollisionShape3D: hijo.set_deferred("disabled", true)
			if hitbox_ataque: hitbox_ataque.set_deferred("monitoring", false)
			
			_reproducir_animacion("muerte")
			if sprite_animado and sprite_animado.sprite_frames.has_animation("muerte"):
				if not sprite_animado.animation_finished.is_connected(queue_free):
					sprite_animado.animation_finished.connect(queue_free)
			else:
				await get_tree().create_timer(1.0).timeout
				queue_free()

# --- DETECCIÓN DE DAÑO ENVIADO AL JUGADOR (CORREGIDO) ---
func _on_hitbox_ataque_body_entered(body: Node3D) -> void:
	if estado_actual == EstadosRueda.MUERTO or estado_actual == EstadosRueda.COOLDOWN or estado_actual == EstadosRueda.ATURDIDO: return
	
	if body == jugador:
		if estado_actual == EstadosRueda.RODANDO:
			print("💥 ¡LA RUEDA ATROPELLÓ AL JUGADOR!")
			if body.has_method("recibir_daño"):
				body.recibir_daño(daño_atropello)
			if body.has_method("aplicar_empuje"):
				# El empuje usa el vector de rodar de la rueda para empujar al jugador hacia atrás con fuerza
				body.aplicar_empuje(direccion_rodar * fuerza_empuje_atropello)
			
			# Al atropellar exitosamente, frena su carrera y entra en cooldown
			cambiar_estado(EstadosRueda.COOLDOWN)
			
		elif estado_actual == EstadosRueda.ATACANDO_MELEE:
			print("⚔️ ¡Golpe cuerpo a cuerpo al jugador!")
			if body.has_method("recibir_daño"):
				body.recibir_daño(daño_espadazo)

# --- CALLBACKS DE TU NUEVO ENEMIGO_BASE (RECIBIR GOLPES) ---
func al_recibir_daño(cantidad: float) -> void:
	print("🛡️ [DAÑO RECIBIDO] Rueda procesando impacto de base: ", cantidad)
	
	# La rueda frena su movimiento lineal al ser golpeada por el jugador
	velocity = Vector3.ZERO
	
	# Si te pegan mientras ruedas o te preparas, te cancelan el ataque
	if estado_actual == EstadosRueda.RODANDO or estado_actual == EstadosRueda.PREPARANDO_GIRO:
		cambiar_estado(EstadosRueda.ATURDIDO)
	elif estado_actual != EstadosRueda.MUERTO:
		cambiar_estado(EstadosRueda.BUSCANDO)

func al_morir() -> void:
	cambiar_estado(EstadosRueda.MUERTO)

# --- AUXILIARES VISUALES ---
func _reproducir_animacion(anim_nombre: String) -> void:
	if sprite_animado and sprite_animado.sprite_frames.has_animation(anim_nombre):
		sprite_animado.play(anim_nombre)

func _ajustar_flip_visual() -> void:
	if jugador == null or sprite_animado == null: return
	var direccion_x = jugador.global_position.x - global_position.x
	if abs(direccion_x) > 0.05:
		sprite_animado.flip_h = direccion_x > 0
