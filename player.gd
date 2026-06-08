extends CharacterBody3D

# --- SEÑALES ---
signal vida_cambiada
signal cargas_cambiadas
signal monedas_cambiadas(cantidad_actual) 
signal inventario_cambiado(items_equipados)
signal pool_rotado(items_visibles) 
signal consumible_cambiado(cantidad)
signal ultimate_cambiada(esta_activa, tiempo_restante) 

# --- NODOS ONREADY ---
@onready var anim: AnimatedSprite3D = $AnimatedSprite3D
@onready var anim_espada: AnimatedSprite3D = $EfectoEspada 
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sfx_caminar_player: AudioStreamPlayer = $SfxCaminar
@onready var sfx_acciones_player: AudioStreamPlayer = $SfxAcciones
@onready var sfx_ulti_player: AudioStreamPlayer = $SfxUlti 
@onready var sfx_cañon_player: AudioStreamPlayer = $SfxCañon 
@onready var area_cañon: Area3D = $cañon 
@onready var colision_cañon: CollisionShape3D = $cañon/CollisionShape3D 
@onready var anim_ulti: AnimatedSprite2D =$anim_ulti

@onready var canvas_layer_shockwave: CanvasLayer = $CanvasLayer
@onready var shockwave_rect: ColorRect = $CanvasLayer/Shockwave

# --- VARIABLES EXPORTADAS ---
@export_category("Estadísticas de Vida")
@export var vida_maxima: float = 100.0
@export var vida_actual: float = 100.0
@export var tiempo_inmunidad: float = 1.0 

@export_category("Animación de Inicio")
@export var tiempo_bloqueo_inicio: float = 3.5 

@export_category("Movimiento")
@export var velocidad_base: float = 6.0
@export var aceleracion: float = 15.0
@export var friccion_empuje_jugador: float = 25.0
var fuerza_empuje_recibido: Vector3 = Vector3.ZERO

@export_category("Mecánica de Rodar")
@export var velocidad_dash: float = 16.0
@export var duracion_dash: float = 0.25
@export var max_cargas_rodar_base: int = 3           
@export var tiempo_recarga_carga: float = 2.0 

@export_category("Combate Básicos")
@export var tiempo_ataque: float = 0.3
@export var daño_ataque_base: float = 10.0
@export var fuerza_impulso_ataque: float = 6.0        
@export var fuerza_empuje_basico_enemigo: float = 4.0        
@export var fuerza_persecucion_atractora: float = 8.0        
@export var rango_autoaim: float = 4.0                                                                                                                                                 
@export var tiempo_stun_basico: float = 0.1                 

@export_category("Habilidad Cañón (E)")
@export var daño_cañon: float = 30.0          
@export var tiempo_ataque_cañon: float = 0.5  
@export var fuerza_empuje_cañon: float = 12.0                
@export var fuerza_retroceso_jugador: float = 14.0 
@export var cooldown_cañon: float = 3.0          

@export_category("Habilidad Combo Q (Estilo Aatrox)")
@export var daño_q_base: float = 12.0
@export var cooldown_q: float = 4.0
@export var ventana_combo_q: float = 1.5

@export_category("Habilidad Ultimate (R)")
@export var duracion_ultimate: float = 8.0
@export var cooldown_ultimate: float = 20.0
@export var multiplicador_daño_ultimate: float = 1.4      
@export var aumento_velocidad_ultimate: float = 3.0       
@export var omnivampirismo_ultimate_base: float = 0.20    
@export var tiempo_congelacion_ultimate: float = 0.2  

var temporizador_veneno: float = 0.0
@export var daño_veneno_tic: float = 2.0

# --- RECURSOS Y AUDIO ---
var sonidos_ataque: Array[AudioStream] = [
	load("res://sfx/sfx.wav"), load("res://sfx/sfx2.wav"),
	load("res://sfx/sfx3.wav"), load("res://sfx/sfx4.wav")
]
var sonidos_daño: Array[AudioStream] = [load("res://sfx/daño.wav"), load("res://sfx/daño2.wav")]
var sonido_dash: AudioStream = load("res://sfx/roll2.wav")
var sonido_muerte: AudioStream = load("res://sfx/muerte.wav")
var sfx_grito_diabolico: AudioStream = load("res://sfx/gritote bien diabolicote.wav")

# --- ESTADOS ---
var esta_atacando: bool = false
var esta_esquivando: bool = false
var esta_usando_cañon: bool = false
var esta_envenenado: bool = false
var esta_en_cooldown_cañon: bool = false
var esta_inmune: bool = false 
var movimiento_bloqueo_inicial: bool = true 
var direccion_mirada: Vector3 = Vector3.FORWARD
var velocidad_actual_dash: Vector3 = Vector3.ZERO
var pantalla_negra: ColorRect = null 
var puede_dashear: bool = true 
var controles_invertidos: bool = false 
var esta_en_cooldown_escudo: bool = false

var esta_en_ultimate: bool = false
var esta_en_cooldown_ultimate: bool = false
var tiempo_restante_ultimate: float = 0.0
var esta_en_animacion_ulti: bool = false 

# --- VARIABLES DE COMBO Q ---
var combo_q_actual: int = 0
var esta_en_cooldown_q: bool = false

# --- ATRIBUTOS DINÁMICOS / INVENTARIO ---
@export var cooldown_escudo_base: float = 12.0
var cantidad_pociones: int = 0
@export var cura_pocion_cantidad: float = 40.0
var cargas_actuales: int = 3
var max_cargas_rodar_modificado: int = 3
var tiempo_acumulado_recarga: float = 0.0
var monedas: int = 20 

var velocidad_modificada: float = 6.0
var daño_ataque_modificado: float = 10.0
var rango_esfera_ataque_modificado: float = 1.8
var reduccion_cooldown: float = 1.0 
var inventario: Array[String] = []
const MAX_SLOTS: int = 6

const TODOS_LOS_ITEMS = ["escudo", "botas", "tobillera", "hoja", "maniqui", "fuelle", "falange", "bomba", "intercambio", "anillo_pacto"]
var pool_actual: Array[String] = [] 
var indice_pool_global: int = 0

const ITEMS_DB = {
	"escudo": {"nombre": "Escudo Guardián", "desc": "ACTIVO: Usa la acción de slot asignada (1-6) para ser inmune por 0.4s (CD: 12s).", "sprite_ruta": "res://texturas/items/escudo.png"},
	"botas": {"nombre": "Botas de Hermes", "desc": "PASIVO: Aumenta la velocidad de movimiento.", "sprite_ruta": "res://texturas/items/botas.png"},
	"tobillera": {"nombre": "Tobillera Eolo", "desc": "PASIVO: Otorga +2 cargas máximas de rodar.", "sprite_ruta": "res://sprites/items/tobillera.png"},
	"hoja": {"nombre": "Hoja Sedienta", "desc": "PASIVO: Otorga 15% de Omnivampirismo al dañar enemigos.", "sprite_ruta": "res://texturas/items/hoja.png"},
	"maniqui": {"nombre": "Extensor de Maniquí", "desc": "PASIVO: Aumenta el rango de la espada, autoaim y cañón.", "sprite_ruta": "res://texturas/items/extensor.png"},
	"fuelle": {"nombre": "Fuelle de Impacto", "desc": "PASIVO: Mayor empuje físico e inflige ralentización de 1s.", "sprite_ruta": "res://texturas/items/fuelle de impacto .png"},
	"falange": {"nombre": "Falange Inquieta", "desc": "PASIVO: Reduce un 30% el Cooldown de habilidades y objetos activos.", "sprite_ruta": "res://sprites/items/falange.png"},
	"bomba": {"nombre": "Bomba de Impacto", "desc": "PASIVO: Tu dash inflige daño y empuja en área a los rivales.", "sprite_ruta": "res://texturas/items/bomba de impulso .jpg"},
	"intercambio": {"nombre": "Intercambio Equivalente", "desc": "PASIVO: A menos vida actual tengas, mayor es tu daño.", "sprite_ruta": "res://texturas/items/intercambio.png"},
	"anillo_pacto": {"nombre": "Sello del Pacto Voraz", "desc": "PASIVO: Consume progresivamente tu vida a cambio de +30% de daño, +50% de monedas y mayor tasa de aparición de objetos.", "sprite_ruta": "res://texturas/items/sello.png"},
	"pocion": {"nombre": "Poción", "desc": "ACTIVO: Regenera salud.", "sprite_ruta": "res://texturas/items/poción.png"}
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS	
	if anim_ulti:
		anim_ulti.visible = false
		anim_ulti.stop()
	if sfx_caminar_player: sfx_caminar_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if sfx_acciones_player: sfx_acciones_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if sfx_ulti_player: sfx_ulti_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if sfx_cañon_player: sfx_cañon_player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	vida_actual = vida_maxima
	add_to_group("jugador")
	if area_cañon: area_cañon.monitoring = true
	if colision_cañon: colision_cañon.disabled = true
	rotar_pool_de_items()
	actualizar_atributos_por_items()
	
	if anim_espada: anim_espada.visible = false
	
	await get_tree().process_frame
	vida_cambiada.emit()
	cargas_cambiadas.emit(cargas_actuales, max_cargas_rodar_modificado)
	monedas_cambiadas.emit(monedas) 
	consumible_cambiado.emit(cantidad_pociones)
	comenzar_bloqueo_inicial()

func comenzar_bloqueo_inicial() -> void:
	movimiento_bloqueo_inicial = true
	await get_tree().create_timer(tiempo_bloqueo_inicio).timeout
	movimiento_bloqueo_inicial = false

func _physics_process(delta: float) -> void:
	if movimiento_bloqueo_inicial:
		reproducir_sfx_caminar(false)
		velocity = Vector3.ZERO
		move_and_slide()
		actualizar_animacion()
		return

	if inventario.has("anillo_pacto") and vida_actual > 0:
		temporizador_veneno += delta
		if temporizador_veneno >= 1.0:
			temporizador_veneno = 0.0
			vida_actual = clamp(vida_actual - daño_veneno_tic, 1.0, vida_maxima)
			vida_cambiada.emit()

	if esta_en_ultimate and not esta_en_animacion_ulti:
		procesar_temporizador_ultimate(delta)

	procesar_recarga_rodar(delta)
	procesar_pruebas_daño()
	procesar_inputs_activos()
	fuerza_empuje_recibido = fuerza_empuje_recibido.move_toward(Vector3.ZERO, friccion_empuje_jugador * delta)

	if esta_en_animacion_ulti:
		reproducir_sfx_caminar(false)
		velocity = Vector3.ZERO 
		move_and_slide()
		actualizar_animacion()
		return

	if esta_esquivando:
		reproducir_sfx_caminar(false)
		velocity = velocidad_actual_dash + fuerza_empuje_recibido
		move_and_slide()
		chequear_colisiones_proyectil()
		actualizar_animacion()
		return
		
	if esta_usando_cañon:
		reproducir_sfx_caminar(false)
		velocity.x = move_toward(velocity.x, 0.0, fuerza_retroceso_jugador * 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, fuerza_retroceso_jugador * 2.0 * delta)
		velocity += fuerza_empuje_recibido
		move_and_slide()
		chequear_colisiones_proyectil()
		actualizar_animacion()
		return

	if esta_atacando:
		reproducir_sfx_caminar(false)
		velocity.x = move_toward(velocity.x, 0.0, aceleracion * delta)
		velocity.z = move_toward(velocity.z, 0.0, aceleracion * delta)
		velocity += fuerza_empuje_recibido
		move_and_slide()
		chequear_colisiones_proyectil()
		actualizar_animacion()
		return
		
	procesar_movimiento(delta)
	procesar_combate()
	chequear_colisiones_proyectil()
	actualizar_animacion()

func actualizar_animacion() -> void:
	if vida_actual <= 0.0:
		if anim and anim.animation != "muerte":
			anim.play("muerte")
		if anim_espada: anim_espada.visible = false
		return

	anim.sprite_frames.set_animation_speed("roll", 8.0)
	anim.sprite_frames.set_animation_speed("idle", 15.0)
	anim.sprite_frames.set_animation_speed("walk", 15.0)

	if esta_en_ultimate:
		anim.modulate = Color(0.3, 0.3, 0.3, 1.0) 
	else:
		anim.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if esta_en_animacion_ulti:
		anim.play("idle") 
		if anim_espada: anim_espada.visible = false
		return

	if esta_esquivando:
		anim.play("roll")
		if anim_espada: anim_espada.visible = false
		if direccion_mirada.x != 0:
			anim.flip_h = direccion_mirada.x < 0
		return

	if esta_atacando:
		anim.play("ataque_caballero")
		if anim_espada:
			anim_espada.visible = true
			anim_espada.play("ataque_espada")
			anim_espada.flip_h = direccion_mirada.x > 0
		if direccion_mirada.x != 0:
			anim.flip_h = direccion_mirada.x > 0
		return
	else:
		if anim_espada: anim_espada.visible = false

	if esta_usando_cañon:
		anim.play("cañonazo")
		if direccion_mirada.x != 0:
			anim.flip_h = direccion_mirada.x < 0
		return

	if velocity.length() > 0.5:
		anim.play("walk")
	else:
		anim.play("idle")
	
	if direccion_mirada.x != 0:
		anim.flip_h = direccion_mirada.x > 0

func procesar_movimiento(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("right"): input_dir.x += 1.0
	if Input.is_action_pressed("left"): input_dir.x -= 1.0
	if Input.is_action_pressed("backward"): input_dir.z += 1.0
	if Input.is_action_pressed("forward"): input_dir.z -= 1.0
	input_dir = input_dir.normalized()
	
	if controles_invertidos: input_dir = -input_dir
	var velocidad_objetivo = input_dir * velocidad_modificada
	velocity.x = move_toward(velocity.x, velocidad_objetivo.x, aceleracion * delta)
	velocity.z = move_toward(velocity.z, velocidad_objetivo.z, aceleracion * delta)
	
	if input_dir != Vector3.ZERO:
		direccion_mirada = input_dir
		var angulo_objetivo = atan2(-input_dir.x, -input_dir.z)
		rotation.y = lerp_angle(rotation.y, angulo_objetivo, delta * 15.0)
		reproducir_sfx_caminar(true)
	else:
		reproducir_sfx_caminar(false)
	
	velocity += fuerza_empuje_recibido
	move_and_slide()

func aplicar_empuje(vector_fuerza: Vector3) -> void:
	fuerza_empuje_recibido = vector_fuerza

func reproducir_sfx_caminar(activar: bool) -> void:
	if !sfx_caminar_player or !sfx_caminar_player.stream: return
	if activar:
		if !sfx_caminar_player.playing: sfx_caminar_player.play()
	else:
		if sfx_caminar_player.playing: sfx_caminar_player.stop()

func procesar_combate() -> void:
	if esta_en_animacion_ulti: return 
	
	if Input.is_action_just_pressed("rodar") and not esta_esquivando and not esta_atacando and not esta_usando_cañon and puede_dashear:
		if cargas_actuales > 0: ejecutar_dash()
		return
	if Input.is_action_just_pressed("attack") and not esta_atacando and not esta_esquivando and not esta_usando_cañon:
		ejecutar_attack()
		return
	if Input.is_action_just_pressed("habilidad_e") and not esta_atacando and not esta_esquivando and not esta_usando_cañon:
		if not esta_en_cooldown_cañon: ejecutar_cañon()
		return
	if Input.is_action_just_pressed("habilidad_q") and not esta_atacando and not esta_esquivando and not esta_usando_cañon:
		if not esta_en_cooldown_q: ejecutar_combo_q()
		return
	if Input.is_action_just_pressed("habilidad_r") and not esta_en_cooldown_ultimate and not esta_esquivando:
		ejecutar_ultimate()
		return

func ejecutar_dash() -> void:
	esta_esquivando = true
	cargas_actuales -= 1 
	if sonido_dash and sfx_acciones_player:
		sfx_acciones_player.stream = sonido_dash
		sfx_acciones_player.play()
	cargas_cambiadas.emit(cargas_actuales, max_cargas_rodar_modificado)
	velocidad_actual_dash = direccion_mirada * velocidad_dash
	if inventario.has("bomba"): ejecutar_explosion_bomba_dash()
	await get_tree().create_timer(duracion_dash).timeout
	esta_esquivando = false

func ejecutar_explosion_bomba_dash() -> void:
	var espacio_3d = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphereshape = SphereShape3D.new()
	sphereshape.radius = 3.0 
	query.shape = sphereshape
	query.transform = global_transform
	query.exclude = [get_rid()]
	var impactos = espacio_3d.intersect_shape(query)
	for impacto in impactos:
		var victima = impacto["collider"]
		if victima.has_method("recibir_daño") and victima.is_in_group("enemigos"):
			var dmg = 15.0
			if esta_en_ultimate: dmg *= multiplicador_daño_ultimate
			victima.recibir_daño(dmg) 
			calcular_y_aplicar_omnivampirismo(dmg)
			var dir = (victima.global_position - global_position).normalized()
			dir.y = 0
			_aplicar_fuerza_y_stun_a_enemigo(victima, dir, 10.0, 0.2)

func procesar_recarga_rodar(delta: float) -> void:
	if cargas_actuales >= max_cargas_rodar_modificado:
		tiempo_acumulado_recarga = 0.0
		return
	tiempo_acumulado_recarga += delta
	if tiempo_acumulado_recarga >= tiempo_recarga_carga:
		cargas_actuales += 1
		tiempo_acumulado_recarga = 0.0 
		cargas_cambiadas.emit(cargas_actuales, max_cargas_rodar_modificado)

func ejecutar_attack() -> void:
	esta_atacando = true
	if anim_espada: anim_espada.frame = 0
		
	var camara = get_viewport().get_camera_3d()
	if camara:
		var mouse_pos = get_viewport().get_mouse_position()
		var rayo_origen = camara.project_ray_origin(mouse_pos)
		var rayo_direccion = camara.project_ray_normal(mouse_pos)
		var plano_jugador = Plane(Vector3.UP, global_position.y)
		var punto_interseccion = plano_jugador.intersects_ray(rayo_origen, rayo_direccion)
		if punto_interseccion:
			var direccion_raton = (punto_interseccion - global_position).normalized()
			direccion_raton.y = 0
			if direccion_raton.length() > 0.1: direccion_mirada = direccion_raton
			
	var enemigo_objetivo = obtener_enemigo_cercano_autoaim()
	if enemigo_objetivo:
		direccion_mirada = (enemigo_objetivo.global_position - global_position).normalized()
		direccion_mirada.y = 0
		
	rotation.y = atan2(-direccion_mirada.x, -direccion_mirada.z)
	velocity = direccion_mirada * fuerza_impulso_ataque
	
	if sfx_acciones_player:
		var audios_validos = sonidos_ataque.filter(func(s): return s != null)
		if audios_validos.size() > 0:
			sfx_acciones_player.stream = audios_validos.pick_random()
			sfx_acciones_player.play()
			
	var daño_final = daño_ataque_modificado
	if inventario.has("intercambio"):
		var porcentaje_vida_perdida = 1.0 - (vida_actual / vida_maxima)
		daño_final += daño_ataque_modificado * porcentaje_vida_perdida * 1.5
		
	if esta_en_ultimate:
		daño_final *= multiplicador_daño_ultimate

	var espacio_3d = get_world_3d().direct_space_state
	var query_ataque = PhysicsShapeQueryParameters3D.new()
	var esfera_ataque = SphereShape3D.new()
	esfera_ataque.radius = rango_esfera_ataque_modificado 
	query_ataque.shape = esfera_ataque
	
	var transform_golpe = global_transform
	var factor_distancia = 2.2 if inventario.has("maniqui") else 1.5
	transform_golpe.origin += direccion_mirada * factor_distancia
	query_ataque.transform = transform_golpe
	query_ataque.collide_with_bodies = true
	query_ataque.collide_with_areas = true 
	query_ataque.exclude = [get_rid()] 
	
	var golpes = espacio_3d.intersect_shape(query_ataque)
	var golpeo_enemigo_valido: bool = false 
	
	for golpe in golpes:
		var victima = golpe["collider"]
		if victima.has_method("recibir_daño"):
			victima.recibir_daño(daño_final)
			if victima.is_in_group("enemigos"):
				golpeo_enemigo_valido = true
				if inventario.has("fuelle") and victima.has_method("aplicar_ralentizacion"):
					victima.aplicar_ralentizacion(1.0) 
		if victima is CharacterBody3D or victima is RigidBody3D:
			var dir_empuje = (victima.global_position - global_position).normalized()
			dir_empuje.y = 0
			var fuerza_final_empuje = fuerza_empuje_basico_enemigo
			if inventario.has("fuelle"): fuerza_final_empuje += 2.5
			_aplicar_fuerza_y_stun_a_enemigo(victima, dir_empuje, fuerza_final_empuje, tiempo_stun_basico)
			velocity = dir_empuje * fuerza_persecucion_atractora
			
	if golpeo_enemigo_valido:
		calcular_y_aplicar_omnivampirismo(daño_final)
		
	await get_tree().create_timer(tiempo_ataque).timeout
	esta_atacando = false

func ejecutar_combo_q() -> void:
	esta_atacando = true 
	combo_q_actual += 1
	if anim_espada: anim_espada.frame = 0
	
	var camara = get_viewport().get_camera_3d()
	if camara:
		var mouse_pos = get_viewport().get_mouse_position()
		var rayo_origen = camara.project_ray_origin(mouse_pos)
		var rayo_direccion = camara.project_ray_normal(mouse_pos)
		var plano_jugador = Plane(Vector3.UP, global_position.y)
		var punto_interseccion = plano_jugador.intersects_ray(rayo_origen, rayo_direccion)
		if punto_interseccion:
			var direccion_raton = (punto_interseccion - global_position).normalized()
			direccion_raton.y = 0
			if direccion_raton.length() > 0.1: direccion_mirada = direccion_raton
			
	var enemigo_objetivo = obtener_enemigo_cercano_autoaim()
	if enemigo_objetivo:
		direccion_mirada = (enemigo_objetivo.global_position - global_position).normalized()
		direccion_mirada.y = 0
		
	rotation.y = atan2(-direccion_mirada.x, -direccion_mirada.z)
	
	var multiplicador_daño: float = 1.0
	var modificador_rango: float = 1.0
	var impulso_fuerza: float = fuerza_impulso_ataque
	var animacion_3d_efecto: String = ""
	
	match combo_q_actual:
		1:
			multiplicador_daño = 1.0
			modificador_rango = 1.0
			impulso_fuerza = fuerza_impulso_ataque * 0.8
			animacion_3d_efecto = "qprimeraactivacion"
		2:
			multiplicador_daño = 1.25
			modificador_rango = 1.2
			impulso_fuerza = fuerza_impulso_ataque * 0.8
			animacion_3d_efecto = "qprimeraactivacion_2"
		3:
			multiplicador_daño = 1.65
			modificador_rango = 1.5
			impulso_fuerza = fuerza_impulso_ataque * 1.5 
			animacion_3d_efecto = "qprimeraactivacion_3"

	velocity = direccion_mirada * impulso_fuerza
	
	if animation_player and animation_player.has_animation(animacion_3d_efecto):
		animation_player.stop() 
		animation_player.play(animacion_3d_efecto)
	
	if sfx_acciones_player and sonidos_ataque.size() > 0:
		sfx_acciones_player.stream = sonidos_ataque.pick_random()
		sfx_acciones_player.play()
		
	var daño_final = daño_q_base * multiplicador_daño
	if inventario.has("anillo_pacto"): daño_final *= 1.30
	if inventario.has("intercambio"):
		var porcentaje_vida_perdida = 1.0 - (vida_actual / vida_maxima)
		daño_final += daño_final * porcentaje_vida_perdida * 1.5

	if esta_en_ultimate:
		daño_final *= multiplicador_daño_ultimate

	var espacio_3d = get_world_3d().direct_space_state
	var query_q = PhysicsShapeQueryParameters3D.new()
	var sphereshape_q = SphereShape3D.new()
	
	var rango_base_q = rango_esfera_ataque_modificado if inventario.has("maniqui") else 1.8
	sphereshape_q.radius = rango_base_q * modificador_rango
	query_q.shape = sphereshape_q
	
	var transform_golpe = global_transform
	var factor_distancia = 2.0 if combo_q_actual == 3 else 1.5
	transform_golpe.origin += direccion_mirada * factor_distancia
	query_q.transform = transform_golpe
	query_q.collide_with_bodies = true
	query_q.collide_with_areas = false
	query_q.exclude = [get_rid()]
	
	var golpes = espacio_3d.intersect_shape(query_q)
	var golpeo_enemigo_valido: bool = false
	
	for golpe in golpes:
		var victima = golpe["collider"]
		if victima.has_method("recibir_daño"):
			victima.recibir_daño(daño_final)
			if victima.is_in_group("enemigos"):
				golpeo_enemigo_valido = true
				if inventario.has("fuelle") and victima.has_method("aplicar_ralentizacion"):
					victima.aplicar_ralentizacion(1.0)
					
		if victima is CharacterBody3D or victima is RigidBody3D:
			var dir_empuje = (victima.global_position - global_position).normalized()
			dir_empuje.y = 0
			var fuerza_final_empuje = fuerza_empuje_basico_enemigo * (2.0 if combo_q_actual == 3 else 1.0)
			if inventario.has("fuelle"): fuerza_final_empuje += 2.5
			_aplicar_fuerza_y_stun_a_enemigo(victima, dir_empuje, fuerza_final_empuje, tiempo_stun_basico)
			
	if golpeo_enemigo_valido:
		calcular_y_aplicar_omnivampirismo(daño_final)
		
	await get_tree().create_timer(tiempo_ataque).timeout
	esta_atacando = false
	
	if combo_q_actual < 3:
		var combo_espera = combo_q_actual
		await get_tree().create_timer(ventana_combo_q).timeout
		if combo_q_actual == combo_espera:
			iniciar_cooldown_q()
	else:
		iniciar_cooldown_q()

func iniciar_cooldown_q() -> void:
	combo_q_actual = 0
	esta_en_cooldown_q = true
	var cd_final = cooldown_q * reduccion_cooldown
	await get_tree().create_timer(cd_final).timeout
	esta_en_cooldown_q = false

func obtener_enemigo_cercano_autoaim() -> Node3D:
	var espacio_3d = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphereshape = SphereShape3D.new()
	sphereshape.radius = rango_autoaim * (1.5 if inventario.has("maniqui") else 1.0)
	query.shape = sphereshape
	query.transform = global_transform
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var resultados = espacio_3d.intersect_shape(query)
	var mejor_objetivo: Node3D = null
	var menor_angulo: float = PI / 3.0 
	for res in resultados:
		var cuerpo = res["collider"]
		if cuerpo.is_in_group("enemigos"):
			var dir_a_enemigo = (cuerpo.global_position - global_position).normalized()
			dir_a_enemigo.y = 0
			var angulo = direccion_mirada.angle_to(dir_a_enemigo)
			if angulo < menor_angulo:
				menor_angulo = angulo
				mejor_objetivo = cuerpo
	return mejor_objetivo

func ejecutar_cañon() -> void:
	esta_usando_cañon = true
	esta_en_cooldown_cañon = true
	
	if sfx_cañon_player:
		sfx_cañon_player.play()
	
	if shockwave_rect and shockwave_rect.material:
		var camara = get_viewport().get_camera_3d()
		if camara:
			var posicion_pantalla = camara.unproject_position(global_position)
			var tamaño_viewport = camara.get_viewport().size
			var centro_normalizado = posicion_pantalla / Vector2(tamaño_viewport)
			shockwave_rect.material.set_shader_parameter("center", centro_normalizado)
			shockwave_rect.material.set_shader_parameter("size", 0.0)
			
			var tween_wave = create_tween()
			tween_wave.tween_property(shockwave_rect.material, "shader_parameter/size", 1.0, tiempo_ataque_cañon)\
				.set_trans(Tween.TRANS_LINEAR)\
				.set_ease(Tween.EASE_OUT)

	var camara = get_viewport().get_camera_3d()
	if camara:
		var mouse_pos = get_viewport().get_mouse_position()
		var rayo_origen = camara.project_ray_origin(mouse_pos)
		var rayo_direccion = camara.project_ray_normal(mouse_pos)
		var plano_jugador = Plane(Vector3.UP, global_position.y)
		var punto_interseccion = plano_jugador.intersects_ray(rayo_origen, rayo_direccion)
		if punto_interseccion:
			var direccion_raton = (punto_interseccion - global_position).normalized()
			direccion_raton.y = 0
			if direccion_raton.length() > 0.1:
				direccion_mirada = direccion_raton
				rotation.y = atan2(-direccion_raton.x, -direccion_raton.z)
				
	velocity = (-direccion_mirada) * fuerza_retroceso_jugador
	if inventario.has("maniqui") and area_cañon: area_cañon.scale = Vector3(1.6, 1.0, 1.6)
	else: if area_cañon: area_cañon.scale = Vector3.ONE
		
	if colision_cañon: colision_cañon.set_deferred("disabled", false)
	await get_tree().physics_frame
	
	if area_cañon:
		var cuerpos_alrededor = area_cañon.get_overlapping_bodies()
		for cuerpo in cuerpos_alrededor: 
			_on_cañon_body_entered(cuerpo)
			
	if colision_cañon: colision_cañon.set_deferred("disabled", true)
	await get_tree().create_timer(tiempo_ataque_cañon).timeout
	if area_cañon: area_cañon.scale = Vector3.ONE 
	esta_usando_cañon = false
	
	var cd_final_cañon = max(0.0, (cooldown_cañon - tiempo_ataque_cañon) * reduccion_cooldown)
	await get_tree().create_timer(cd_final_cañon).timeout
	esta_en_cooldown_cañon = false

# --- LÓGICA DE LA HABILIDAD DEFINITIVA (ULTIMATE) CON ZOOM PROGRESIVO Y DASH ---
func ejecutar_ultimate() -> void:
	if esta_en_cooldown_ultimate or esta_en_ultimate or esta_en_animacion_ulti:
		return
	
	esta_en_ultimate = true
	esta_en_animacion_ulti = true
	esta_en_cooldown_ultimate = true
	tiempo_restante_ultimate = duracion_ultimate
	
	ultimate_cambiada.emit(true, tiempo_restante_ultimate)
	
	# === ANIMACIÓN NUEVA ===
	if anim_ulti:
		anim_ulti.visible = true
		anim_ulti.frame = 0
		anim_ulti.play("ulti")          # ← Cambia "ulti" por el nombre exacto de tu nueva animación
	
	# Sonido
	if sfx_ulti_player and sfx_grito_diabolico:
		sfx_ulti_player.stream = sfx_grito_diabolico
		sfx_ulti_player.play()
	
	# Efecto de cámara + congelación de tiempo
	
	# Dash hacia enemigo + daño
	var enemigo = obtener_enemigo_cercano_autoaim()
	if enemigo and enemigo.has_method("recibir_daño"):
		var dir = (enemigo.global_position - global_position).normalized()
		dir.y = 0
		rotation.y = atan2(-dir.x, -dir.z)
		create_tween().tween_property(self, "global_position", enemigo.global_position + dir * 0.8, tiempo_congelacion_ultimate * 0.8)
		enemigo.recibir_daño(99999.0)
	
	# Esperar la animación de entrada
	await get_tree().create_timer(tiempo_congelacion_ultimate, false).timeout
	
	# Fin de la animación de activación
	if anim_ulti:
		anim_ulti.stop()
		anim_ulti.visible = false
		# anim_ulti.visible = false   # Descomenta si quieres ocultarla
	
	esta_en_animacion_ulti = false
	actualizar_atributos_por_items()
	
	# Duración de la ultimate
	await get_tree().create_timer(duracion_ultimate, false).timeout
	
	esta_en_ultimate = false
	ultimate_cambiada.emit(false, 0.0)
	
	# Cooldown
	var cd_final = cooldown_ultimate * reduccion_cooldown
	await get_tree().create_timer(cd_final, false).timeout
	esta_en_cooldown_ultimate = false

func procesar_temporizador_ultimate(delta: float) -> void:
	tiempo_restante_ultimate = max(0.0, tiempo_restante_ultimate - delta)
	ultimate_cambiada.emit(true, tiempo_restante_ultimate)

func calcular_y_aplicar_omnivampirismo(daño_provocado: float) -> void:
	var porcentaje_vampirismo: float = 0.0
	if inventario.has("hoja"): porcentaje_vampirismo += 0.15
	if esta_en_ultimate: porcentaje_vampirismo += omnivampirismo_ultimate_base
	if porcentaje_vampirismo > 0.0: curar(daño_provocado * porcentaje_vampirismo)

func recibir_daño(cantidad: float) -> void:
	if esta_esquivando or movimiento_bloqueo_inicial or esta_inmune or esta_en_animacion_ulti: return
	vida_actual = clamp(vida_actual - cantidad, 0.0, vida_maxima)
	vida_cambiada.emit()
	if vida_actual <= 0.0:
		morir()
		return
	ejecutar_frames_inmunidad()
	if sfx_acciones_player:
		var audios_validos = sonidos_daño.filter(func(s): return s != null)
		if audios_validos.size() > 0:
			sfx_acciones_player.stream = audios_validos.pick_random()
			sfx_acciones_player.play()

func ejecutar_frames_inmunidad() -> void:
	esta_inmune = true
	await get_tree().create_timer(tiempo_inmunidad).timeout
	esta_inmune = false

func curar(cantidad: float) -> void:
	if vida_actual <= 0.0: return
	vida_actual = clamp(vida_actual + cantidad, 0.0, vida_maxima)
	vida_cambiada.emit()

func morir() -> void:
	reproducir_sfx_caminar(false)
	esta_en_ultimate = false 
	esta_en_animacion_ulti = false
	Engine.time_scale = 1.0
	
	if sonido_muerte and sfx_acciones_player:
		sfx_acciones_player.stream = sonido_muerte
		sfx_acciones_player.play()
		
	movimiento_bloqueo_inicial = true
	velocity = Vector3.ZERO
	
	if anim and anim.sprite_frames.has_animation("muerte"):
		anim.sprite_frames.set_animation_loop("muerte", false)
		anim.play("muerte")
		
	if anim_espada: anim_espada.visible = false
		
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100 
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS 
	get_tree().root.add_child(canvas_layer)
	pantalla_negra = ColorRect.new()
	pantalla_negra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) 
	pantalla_negra.color = Color(0, 0, 0, 0) 
	canvas_layer.add_child(pantalla_negra)
	
	var tween = create_tween()
	tween.tween_property(pantalla_negra, "color", Color(0, 0, 0, 1), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	var arbol_escena = get_tree()
	await arbol_escena.create_timer(2.5).timeout 
	if arbol_escena: 
		canvas_layer.queue_free()
		set_physics_process(false)
		set_process(false)
		arbol_escena.call_deferred("reload_current_scene")

func procesar_pruebas_daño() -> void:
	if Input.is_key_pressed(KEY_K):
		if Engine.get_physics_frames() % 10 == 0: recibir_daño(15.0)

func _on_cañon_body_entered(body: Node3D) -> void:
	if body == self: return 
	
	var dmg = daño_cañon
	if esta_en_ultimate: dmg *= multiplicador_daño_ultimate
	
	if body.has_method("recibir_daño"): 
		body.recibir_daño(dmg)
		calcular_y_aplicar_omnivampirismo(dmg)
		
	var direccion_empuje = (body.global_position - global_position).normalized()
	direccion_empuje.y = 0 
	var fuerza_final_cañon = fuerza_empuje_cañon
	if inventario.has("fuelle"): fuerza_final_cañon += 4.0
	_aplicar_fuerza_y_stun_a_enemigo(body, direccion_empuje, fuerza_final_cañon, 0.2)

func _aplicar_fuerza_y_stun_a_enemigo(enemigo: Node3D, direccion: Vector3, fuerza: float, tiempo_stun: float) -> void:
	if enemigo.has_method("recibir_stun"): enemigo.recibir_stun(tiempo_stun)
	if enemigo.has_method("aplicar_empuje"): enemigo.aplicar_empuje(direccion * fuerza)
	elif "velocity" in enemigo: enemigo.velocity += direccion * fuerza

func añadir_monedas(cantidad: int) -> void:
	var cantidad_final = cantidad
	if inventario.has("anillo_pacto"): cantidad_final = int(cantidad * 1.5)
	monedas += cantidad_final
	monedas_cambiadas.emit(monedas)
	if animation_player and animation_player.has_animation("agarrar_moneda"):
		animation_player.play("agarrar_moneda")

func chequear_colisiones_proyectil() -> void:
	if movimiento_bloqueo_inicial: return
	var espacio_3d = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphereshape = SphereShape3D.new()
	sphereshape.radius = 0.6 
	query.shape = sphereshape
	query.transform = global_transform
	query.collide_with_areas = true 
	query.collide_with_bodies = false
	var resultados = espacio_3d.intersect_shape(query)
	for resultado in resultados:
		var objeto = resultado["collider"]
		if objeto and "es_proyectil_enemigo" in objeto:
			objeto.queue_free()
			break

func procesar_inputs_activos() -> void:
	if esta_en_animacion_ulti: return 

	if Input.is_action_just_pressed("usar_pocion"):
		if cantidad_pociones > 0 and vida_actual < vida_maxima:
			cantidad_pociones -= 1
			curar(cura_pocion_cantidad)
			consumible_cambiado.emit(cantidad_pociones)

	var acciones_slots = ["activar_slot_1", "activar_slot_2", "activar_slot_3", "activar_slot_4", "activar_slot_5", "activar_slot_6"]
	for i in range(acciones_slots.size()):
		if Input.is_action_just_pressed(acciones_slots[i]):
			if inventario.size() > i and inventario[i] == "escudo": 
				intentar_activar_escudo()

func intentar_activar_escudo() -> void:
	if esta_en_cooldown_escudo: return
	esta_en_cooldown_escudo = true
	esta_inmune = true
	await get_tree().create_timer(0.4).timeout
	esta_inmune = false
	var cd_final_escudo = cooldown_escudo_base * reduccion_cooldown
	await get_tree().create_timer(cd_final_escudo).timeout
	esta_en_cooldown_escudo = false

func equipar_item(id_item: String) -> void:
	if id_item == "pocion":
		cantidad_pociones += 1
		consumible_cambiado.emit(cantidad_pociones)
		return
	if inventario.has(id_item): return
	if inventario.size() >= MAX_SLOTS: inventario.pop_front()
	inventario.append(id_item)
	actualizar_atributos_por_items()
	inventario_cambiado.emit(inventario)

func actualizar_atributos_por_items() -> void:
	velocidad_modificada = velocidad_base
	daño_ataque_modificado = daño_ataque_base
	daño_cañon = 30.0
	rango_esfera_ataque_modificado = 1.8
	max_cargas_rodar_modificado = max_cargas_rodar_base
	reduccion_cooldown = 1.0 
	
	for item in inventario:
		match item:
			"botas": velocidad_modificada += 3.5
			"tobillera": max_cargas_rodar_modificado += 2 
			"maniqui": rango_esfera_ataque_modificado = 2.8 
			"falange": reduccion_cooldown = 0.7 
			
	if inventario.has("anillo_pacto"):
		daño_ataque_modificado *= 1.30
		daño_cañon *= 1.30
		
	if esta_en_ultimate: velocidad_modificada += aumento_velocidad_ultimate
		
	cargas_actuales = min(cargas_actuales, max_cargas_rodar_modificado)
	cargas_cambiadas.emit(cargas_actuales, max_cargas_rodar_modificado)

func rotar_pool_de_items() -> void:
	pool_actual.clear()
	var copia_items = TODOS_LOS_ITEMS.duplicate()
	copia_items.erase("botas")
	copia_items.erase("intercambio")
	copia_items.shuffle()
	pool_actual.append("botas")
	pool_actual.append("intercambio")
	pool_actual.append(copia_items[0])
	pool_rotado.emit(pool_actual)

func obtener_tasa_aparicion_objects() -> float:
	if inventario.has("anillo_pacto"): return 1.5
	return 1.0
