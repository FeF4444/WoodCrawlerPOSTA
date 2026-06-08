extends Node3D

# --- PRECARGA DE ENEMIGOS Y OBJETOS ---
var escena_arbusto: PackedScene = preload("res://arbusto.tscn")
var escena_caballero: PackedScene = preload("res://caballero_fantasma.tscn")
var escena_moneda: PackedScene = preload("res://moneda.tscn")
var escena_esqueleto: PackedScene = preload("res://RuedaEsqueleto.tscn") # 💀 Nuevo enemigo

# --- CONFIGURACIÓN DE ECONOMÍA EXPORTADA ---
@export_group("Economía Enemigos")
@export var factor_atenuacion_monedas: float = 0.35
@export var minimo_monedas_por_enemigo: int = 3
@export var maximo_monedas_por_enemigo: int = 15

@export_group("Economía Destructibles")
@export_range(0.0, 1.0) var probabilidad_moneda_arbusto: float = 0.40
@export var minimo_monedas_arbusto: int = 1
@export var maximo_monedas_arbusto: int = 3

# --- CONFIGURACIÓN DE ESCALADO PROGRESIVO AJUSTADO ---
@export_group("Escalado de Dificultad Justo")
@export var vida_base_caballero: float = 30.0
@export var vida_base_arbusto: float = 20.0
@export var vida_base_esqueleto: float = 25.0 # 📈 Vida base para el esqueleto
@export var factor_crecimiento_inicial: float = 0.25 
@export var atenuacion_curva: float = 0.008            

# --- NODOS ONREADY ---
@onready var room_container: Node3D = $RoomContainer
@onready var barra_vida: ProgressBar = $CanvasLayer/ProgressBarDash/Sprite2D/ProgressBar
@onready var barra_dash: ProgressBar = $CanvasLayer/ProgressBarDash
var jugador: CharacterBody3D = null

# Historial de habitaciones visitadas y control de rutas
var historial_habitaciones: Array[String] = []
var indice_habitacion_actual: int = -1
var historial_entradas: Array[String] = [""]

# Guarda las últimas habitaciones visitadas de forma consecutiva para evitar repeticiones
var ultimas_habitaciones_visitadas: Array[String] = []

# Guarda qué puerta se eligió para SALIR de cada índice de habitación
var historial_salidas_elegidas: Dictionary = {}

# --- DICCIONARIO DE PERSISTENCIA DE HABITACIONES ---
var registro_enemigos_habitaciones: Dictionary = {}

# 🏪 PERSISTENCIA EXCLUSIVA PARA TIENDAS
var registro_tiendas: Dictionary = {}

# Lista de tus habitaciones disponibles estándar (Se removió room2 de aquí para controlarla por dirección)
var pool_de_cuartos: Array[String] = [
	"res://rooms/room1.tscn",
	"res://rooms/room3.tscn",
	"res://rooms/room_tienda.tscn"
]

# --- VARIABLES DE ESTADO DE COMBATE Y TRANSICIÓN ---
var habitacion_bloqueada: bool = false
var cantidad_enemigos_vivos: int = 0
var enemigos_totales_en_sala_actual: int = 1
var cambiando_habitacion: bool = false
var procesando_transicion: bool = false 

func _enter_tree() -> void:
	for hijo in get_children():
		if hijo is CharacterBody3D:
			jugador = hijo
			break

func _ready() -> void:
	historial_habitaciones.append("res://rooms/cuarto_base.tscn")
	registro_enemigos_habitaciones[0] = {"limpia": true} 
	indice_habitacion_actual = 0
	
	cargar_habitacion(0, "") 
	
	if jugador == null:
		print("ADVERTENCIA: No se encontró al jugador en la raíz de Mundo.")
	else:
		_on_jugador_vida_cambiada()
		if "cargas_actuales" in jugador and "max_cargas_rodar_modificado" in jugador:
			_on_jugador_cargas_cambiadas(jugador.cargas_actuales, jugador.max_cargas_rodar_modificado)
		
		if barra_vida:
			jugador.vida_cambiada.connect(_on_jugador_vida_cambiada)
		if barra_dash and jugador.has_signal("cargas_cambiadas"):
			jugador.cargas_cambiadas.connect(_on_jugador_cargas_cambiadas)
			
		if $CanvasLayer.has_node("LabelMonedas"):
			jugador.monedas_cambiadas.connect(func(cant): $CanvasLayer/LabelMonedas.text = "" + str(cant))
			
	get_tree().current_scene = self

func cargar_habitacion(indice: int, puerta_aparicion: String) -> void:
	cambiando_habitacion = true 
	indice_habitacion_actual = indice
	habitacion_bloqueada = false
	cantidad_enemigos_vivos = 0
	
	for cuarto_viejo in room_container.get_children():
		cuarto_viejo.queue_free()
		
	var ruta_a_cargar = historial_habitaciones[indice_habitacion_actual]
	
	# Mantenemos el registro de exclusión sincronizado incluso si el jugador retrocede/re-avanza
	if not ruta_a_cargar in ultimas_habitaciones_visitadas and not ruta_a_cargar.ends_with("cuarto_base.tscn"):
		ultimas_habitaciones_visitadas.append(ruta_a_cargar)
		if ultimas_habitaciones_visitadas.size() > 2:
			var _eliminado = ultimas_habitaciones_visitadas.pop_front()
	
	var nueva_escena = load(ruta_a_cargar) as PackedScene
	
	if nueva_escena:
		var nueva_room = nueva_escena.instantiate()
		
		if ruta_a_cargar.ends_with("cuarto_base.tscn") and indice_habitacion_actual == 0:
			if registro_enemigos_habitaciones.size() > 1: 
				if "reproducir_luz_al_entrar" in nueva_room:
					nueva_room.reproducir_luz_al_entrar = false
		
		room_container.add_child(nueva_room)
		conectar_puertas(nueva_room)
		
		var nombre_cuarto = ruta_a_cargar.get_file() 
		print("--------------------------------------------------")
		print("HABITACIÓN CARGADA: [ ", nombre_cuarto, " ] (Índice: ", indice_habitacion_actual, ")")
		print("--------------------------------------------------")
		
		if not puerta_aparicion.is_empty():
			colocar_jugador_en_puerta(nueva_room, puerta_aparicion)
			
		# --- GESTIÓN DE ENCUENTRO EN ROOM 1 ---
		if nombre_cuarto == "room1.tscn":
			if not registro_enemigos_habitaciones.has(indice_habitacion_actual):
				registro_enemigos_habitaciones[indice_habitacion_actual] = {"limpia": false}
				
			if not registro_enemigos_habitaciones[indice_habitacion_actual]["limpia"]:
				var caballero = escena_caballero.instantiate()
				configurar_vida_escalada(caballero, vida_base_caballero)
				nueva_room.add_child(caballero)
				caballero.global_position = Vector3(0.0, 0.1, 0.0)
				
				if caballero.has_signal("muerto"):
					caballero.muerto.connect(_on_enemigo_muerto.bind(caballero))
				else:
					caballero.tree_exiting.connect(_on_enemigo_muerto.bind(caballero))
				
				cantidad_enemigos_vivos = 1
				activa_modo_combate()
				print("⚔️ [MUNDO]: ¡Un Caballero Fantasma ha aparecido en la Room 1!")
			else:
				print("✨ [MUNDO]: El caballero de esta habitación ya fue derrotado.")
		
		# --- GESTIÓN DE ENEMIGOS EN ROOM 2 (MARCADORES CONFIGURABLES DESDE EL EDITOR) ---
		elif nombre_cuarto == "room2.tscn":
			if not registro_enemigos_habitaciones.has(indice_habitacion_actual):
				registro_enemigos_habitaciones[indice_habitacion_actual] = {"limpia": false}
				
			if not registro_enemigos_habitaciones[indice_habitacion_actual]["limpia"]:
				var nodo_spawn = nueva_room.find_child("SpawnersRoom2", true, false)
				if nodo_spawn:
					# --- Spawn 1: Caballero Fantasma ---
					var marker_caballero = nodo_spawn.find_child("Spawn 1", true, false)
					if marker_caballero and marker_caballero is Node3D:
						var caballero = escena_caballero.instantiate()
						configurar_vida_escalada(caballero, vida_base_caballero)
						nueva_room.add_child(caballero)
						caballero.global_position = marker_caballero.global_position
						
						if caballero.has_signal("muerto"):
							caballero.muerto.connect(_on_enemigo_muerto.bind(caballero))
						else:
							caballero.tree_exiting.connect(_on_enemigo_muerto.bind(caballero))
						
						cantidad_enemigos_vivos += 1
						print("⚔️ [MUNDO]: Caballero Fantasma spawneado en Spawn 1 de la Room 2.")

					# --- Spawns 2 al 11: Arbustos ---
					for i in range(2, 12):
						var nombre_spawn = "Spawn " + str(i)
						var marker_arbusto = nodo_spawn.find_child(nombre_spawn, true, false)
						
						if marker_arbusto and marker_arbusto is Node3D:
							var arbusto = escena_arbusto.instantiate()
							configurar_vida_escalada(arbusto, vida_base_arbusto)
							nueva_room.add_child(arbusto)
							arbusto.global_position = marker_arbusto.global_position
							
							if arbusto.has_signal("muerto"):
								arbusto.muerto.connect(_on_enemigo_muerto.bind(arbusto))
							else:
								arbusto.tree_exiting.connect(_on_enemigo_muerto.bind(arbusto))
								
							if arbusto.has_signal("revelado"):
								arbusto.revelado.connect(_on_enemigo_revelado)
								
							cantidad_enemigos_vivos += 1
					
					if cantidad_enemigos_vivos > 0:
						activa_modo_combate()
						print("⚔️ [MUNDO]: ¡Room 2 cargada con ", cantidad_enemigos_vivos, " enemigos desde sus marcadores!")
				else:
					print("ADVERTENCIA: No se encontró el nodo 'SpawnersRoom2' en la Room 2.")
			else:
				print("✨ [MUNDO]: Los enemigos de la Room 2 ya fueron derrotados anteriormente.")

		# --- GESTIÓN DE ENEMIGOS EN ROOM 3 ---
		elif nombre_cuarto == "room3.tscn":
			if not registro_enemigos_habitaciones.has(indice_habitacion_actual):
				registro_enemigos_habitaciones[indice_habitacion_actual] = {"limpia": false}
			
			if not registro_enemigos_habitaciones[indice_habitacion_actual]["limpia"]:
				var limite_x_min: float = -6.0
				var limite_x_max: float = 6.0
				var limite_z_min: float = -6.0
				var limite_z_max: float = 6.0
				
				var distancia_minima_separacion: float = 3.5 
				var posiciones_ocupadas: Array[Vector3] = []
				
				for i in range(4):
					var nuevo_enemigo = escena_arbusto.instantiate()
					configurar_vida_escalada(nuevo_enemigo, vida_base_arbusto)
					nueva_room.add_child(nuevo_enemigo)
					
					var pos_final = Vector3.ZERO
					var posicion_valida = false
					var intentos = 0
					
					while not posicion_valida and intentos < 100:
						intentos += 1
						var rand_x = randf_range(limite_x_min, limite_x_max)
						var rand_z = randf_range(limite_z_min, limite_z_max)
						pos_final = Vector3(rand_x, 0.1, rand_z)
						
						var demasiado_cerca = false
						for pos_existente in posiciones_ocupadas:
							if pos_final.distance_to(pos_existente) < distancia_minima_separacion:
								demasiado_cerca = true
								break 
						
						if not demasiado_cerca:
							posicion_valida = true
					
					posiciones_ocupadas.append(pos_final)
					nuevo_enemigo.global_position = pos_final
					
					if nuevo_enemigo.has_signal("muerto"):
						nuevo_enemigo.muerto.connect(_on_enemigo_muerto.bind(nuevo_enemigo))
					else:
						nuevo_enemigo.tree_exiting.connect(_on_enemigo_muerto.bind(nuevo_enemigo))
						
					if nuevo_enemigo.has_signal("revelado"):
						nuevo_enemigo.revelado.connect(_on_enemigo_revelado)
						
					cantidad_enemigos_vivos += 1
				print("🎲 [MUNDO]: 4 arbustos esparcidos en la Room 3.")
			else:
				print("✨ [MUNDO]: Esta habitación ya fue completada previamente.")
				
		# --- GESTIÓN DE ENEMIGOS EN PASILLO 1 (MARCADORES ESPECÍFICOS CORREGIDOS) ---
		elif nombre_cuarto == "pasillo_1.tscn":
			if not registro_enemigos_habitaciones.has(indice_habitacion_actual):
				registro_enemigos_habitaciones[indice_habitacion_actual] = {"limpia": false}
				
			if not registro_enemigos_habitaciones[indice_habitacion_actual]["limpia"]:
				var nodo_spawn = nueva_room.find_child("SpawnersEnemigos", true, false)
				if nodo_spawn:
					var nombres_spawns = ["Spawn 1", "Spawn 2", "Spawn 3"]
					for nombre in nombres_spawns:
						var marker = nodo_spawn.find_child(nombre, true, false)
						if marker and marker is Node3D:
							var esqueleto = escena_esqueleto.instantiate()
							configurar_vida_escalada(esqueleto, vida_base_esqueleto)
							nueva_room.add_child(esqueleto)
							esqueleto.global_position = marker.global_position
							
							if esqueleto.has_signal("muerto"):
								esqueleto.muerto.connect(_on_enemigo_muerto.bind(esqueleto))
							else:
								esqueleto.tree_exiting.connect(_on_enemigo_muerto.bind(esqueleto))
								
							cantidad_enemigos_vivos += 1
					
					if cantidad_enemigos_vivos > 0:
						activa_modo_combate()
						print("💀 [MUNDO]: Spawneadas ", cantidad_enemigos_vivos, " Ruedas Esqueleto en los marcadores de Pasillo 1.")
				else:
					print("ADVERTENCIA: No se encontró el nodo 'SpawnersEnemigos' en Pasillo 1.")
			else:
				print("✨ [MUNDO]: Los enemigos de Pasillo 1 ya fueron derrotados.")

		# --- GESTIÓN PERSISTENTE DE LA TIENDA CON CONSUMIBLE FIJO ---
		elif nombre_cuarto == "room_tienda.tscn" or nueva_room.has_method("inicializar_tienda"):
			if not registro_enemigos_habitaciones.has(indice_habitacion_actual):
				registro_enemigos_habitaciones[indice_habitacion_actual] = {"limpia": true}
			
			if jugador:
				if not registro_tiendas.has(indice_habitacion_actual):
					var nuevo_pool: Array[String] = []
					
					# 🧪 SLOT 1: Siempre es la poción consumible
					nuevo_pool.append("pocion")
					
					# SLOTS 2 Y 3: Equipamiento aleatorio desde TODOS_LOS_ITEMS del player
					for i in range(2):
						var idx = (jugador.indice_pool_global + i) % jugador.TODOS_LOS_ITEMS.size()
						nuevo_pool.append(jugador.TODOS_LOS_ITEMS[idx])
					
					# Rotamos el índice de la pool global del jugador para futuras tiendas
					jugador.indice_pool_global = (jugador.indice_pool_global + 2) % jugador.TODOS_LOS_ITEMS.size()
					
					registro_tiendas[indice_habitacion_actual] = nuevo_pool.duplicate()
					jugador.pool_actual = nuevo_pool.duplicate()
					print("🆕 [TIENDA #", indice_habitacion_actual, "]: Slot 1 -> Poción fija. Slots 2 y 3 -> Equipos.")
				else:
					jugador.pool_actual = registro_tiendas[indice_habitacion_actual].duplicate()
					print("📦 [TIENDA #", indice_habitacion_actual, "]: Cargando stock persistente.")
			
			# Comunicamos los ítems a la escena de la tienda instalada
			if nueva_room.has_method("inicializar_tienda"):
				nueva_room.inicializar_tienda(jugador, indice_habitacion_actual, self)
			
		else:
			if not registro_enemigos_habitaciones.has(indice_habitacion_actual):
				registro_enemigos_habitaciones[indice_habitacion_actual] = {"limpia": true}
		
		# === 💀 SPAWN CONTROLADO DEL ESQUELETO SODOMI ===
		# Se ejecuta SOLO si la escena de la habitación tiene una variable 'quiere_esqueleto' puesta en true
		if "quiere_esqueleto" in nueva_room and nueva_room.quiere_esqueleto:
			if not registro_enemigos_habitaciones[indice_habitacion_actual]["limpia"]:
				var esqueleto = escena_esqueleto.instantiate()
				configurar_vida_escalada(esqueleto, vida_base_esqueleto)
				nueva_room.add_child(esqueleto)
				
				# Generamos una posición aleatoria para el esqueleto dentro del rango jugable
				var rand_x = randf_range(-4.5, 4.5)
				var rand_z = randf_range(-4.5, 4.5)
				esqueleto.global_position = Vector3(rand_x, 0.1, rand_z)
				
				# Conexión de señales para el sistema de combate de Mundo
				if esqueleto.has_signal("muerto"):
					esqueleto.muerto.connect(_on_enemigo_muerto.bind(esqueleto))
				else:
					esqueleto.tree_exiting.connect(_on_enemigo_muerto.bind(esqueleto))
				
				cantidad_enemigos_vivos += 1
				activa_modo_combate()
				print("💀 [MUNDO]: ¡Un Esqueleto Sodomi ha sido solicitado por la escena y se une al combate!")
		
		conectar_destructibles_recursivo(nueva_room)

	enemigos_totales_en_sala_actual = cantidad_enemigos_vivos if cantidad_enemigos_vivos > 0 else 1
				
	cambiando_habitacion = false
	get_tree().create_tween().tween_callback(func(): procesando_transicion = false).set_delay(0.1)

func configurar_vida_escalada(enemigo: Node3D, vida_base: float) -> void:
	if "vida" in enemigo:
		var salas_de_peligro: int = 0
		if indice_habitacion_actual >= 2:
			var sala_desfasada = (indice_habitacion_actual - 2) + 1
			salas_de_peligro = sala_desfasada
		
		var tasa_crecimiento_actual = factor_crecimiento_inicial - (atenuacion_curva * (salas_de_peligro - 1 if salas_de_peligro > 0 else 0))
		tasa_crecimiento_actual = max(tasa_crecimiento_actual, 0.05)
		
		var multiplicador_curva: float = 1.0
		if salas_de_peligro > 0:
			multiplicador_curva = 1.0 + (tasa_crecimiento_actual * salas_de_peligro)
		
		var vida_progresiva = vida_base * multiplicador_curva
		var variacion_aleatoria = randf_range(0.9, 1.1)
		var vida_final = vida_progresiva * variacion_aleatoria
		
		enemigo.vida = max(vida_final, vida_base)
		
		print("📈 [DIFICULTAD PROGRESIVA] Sala: ", indice_habitacion_actual, " | Peligro Nivel: ", salas_de_peligro)
		print("👾 Enemigo instanciado con: ", int(enemigo.vida), " HP (Base: ", vida_base, ")")

func conectar_destructibles_recursivo(nodo: Node) -> void:
	if nodo.has_signal("destruido"):
		if nodo.destruido.is_connected(_on_arbusto_decorativo_destruido):
			nodo.destruido.disconnect(_on_arbusto_decorativo_destruido)
		nodo.destruido.connect(_on_arbusto_decorativo_destruido)
	
	for hijo in nodo.get_children():
		conectar_destructibles_recursivo(hijo)

func conectar_puertas(cuarto_nodo: Node) -> void:
	var direcciones = ["norte", "sur", "este", "oeste"]
	for dir in direcciones:
		var nombre_puerta = "salida " + dir
		var puerta = cuarto_nodo.find_child(nombre_puerta, true, false)
		
		if puerta and puerta.has_signal("body_entered"):
			for conexion in puerta.body_entered.get_connections():
				puerta.body_entered.disconnect(conexion.callable)
				
			var callback = _on_puerta_tocada.bind(dir)
			puerta.body_entered.connect(callback)

func _on_puerta_tocada(body: Node3D, direccion_puerta: String) -> void:
	if jugador == null or body != jugador:
		return
		
	if procesando_transicion:
		return
		
	if habitacion_bloqueada:
		print("🚫 [MUNDO]: ¡Las puertas están selladas! Quedan ", cantidad_enemigos_vivos, " enemigos.")
		if "direccion_mirada" in jugador:
			jugador.velocity = -jugador.direccion_mirada * 4.0
		return

	var puerta_de_entrada_a_esta_sala = historial_entradas[indice_habitacion_actual]
	var es_retroceso = (indice_habitacion_actual > 0 and direccion_puerta == puerta_de_entrada_a_esta_sala)

	if not es_retroceso:
		if historial_salidas_elegidas.has(indice_habitacion_actual):
			var salida_permitida = historial_salidas_elegidas[indice_habitacion_actual]
			if direccion_puerta != salida_permitida:
				print("🔒 [CAMINO CERRADO]: Ya elegiste ir por '" + salida_permitida + "' anteriormente.")
				if "direccion_mirada" in jugador:
					jugador.velocity = -jugador.direccion_mirada * 3.0
				return

	procesando_transicion = true
	jugador.velocity = Vector3.ZERO
	
	var mapeo_opuestos = {
		"norte": "sur",
		"sur": "norte",
		"este": "oeste",
		"oeste": "este"
	}
	
	var puerta_aparicion_objetivo = mapeo_opuestos[direccion_puerta]
	
	if es_retroceso:
		var indice_anterior = indice_habitacion_actual - 1
		print("<- RETROCEDIENDO al índice: ", indice_anterior)
		call_deferred("cargar_habitacion", indice_anterior, puerta_aparicion_objetivo)
		return

	if indice_habitacion_actual < historial_habitaciones.size() - 1:
		var siguiente_indice = indice_habitacion_actual + 1
		if historial_entradas[siguiente_indice] == puerta_aparicion_objetivo:
			print("-> RE-AVANZANDO al índice: ", siguiente_indice)
			call_deferred("cargar_habitacion", siguiente_indice, puerta_aparicion_objetivo)
			return
			
		historial_habitaciones = historial_habitaciones.slice(0, indice_habitacion_actual + 1)
		historial_entradas = historial_entradas.slice(0, indice_habitacion_actual + 1)
		for k in registro_enemigos_habitaciones.keys():
			if k > indice_habitacion_actual: registro_enemigos_habitaciones.erase(k)
			if historial_salidas_elegidas.has(k) and k > indice_habitacion_actual: historial_salidas_elegidas.erase(k)
			if registro_tiendas.has(k) and k > indice_habitacion_actual: registro_tiendas.erase(k)

	historial_salidas_elegidas[indice_habitacion_actual] = direccion_puerta

	# --- SELECCIÓN CON COMPETENCIA EXCLUSIVA HACIA EL ESTE (DERECHA) ---
	var pool_temporal = pool_de_cuartos.duplicate()
	
	# Si vas hacia el "este", la room2 y el pasillo entran a competir en igualdad de condiciones
	if direccion_puerta == "este":
		pool_temporal.append("res://rooms/pasillo_1.tscn")
		pool_temporal.append("res://rooms/room2.tscn")
	
	# Filtramos las habitaciones que ya se visitaron recientemente para evitar repeticiones repetitivas
	var cuartos_disponibles = pool_temporal.filter(
		func(cuarto): return not cuarto in ultimas_habitaciones_visitadas
	)
	
	# Failsafe: si por descarte secuencial nos quedamos sin cuartos, usamos la pool temporal construida
	if cuartos_disponibles.is_empty():
		cuartos_disponibles = pool_temporal

	# Selección aleatoria balanceada
	var nueva_ruta = cuartos_disponibles.pick_random()
	# ------------------------------------------------------------

	historial_habitaciones.append(nueva_ruta)
	historial_entradas.append(puerta_aparicion_objetivo)
	
	var nuevo_indice = indice_habitacion_actual + 1
	print("✨ AVANCE -> Índice: ", nuevo_indice, " | Puerta: ", direccion_puerta)
	call_deferred("cargar_habitacion", nuevo_indice, puerta_aparicion_objetivo)

func colocar_jugador_en_puerta(cuarto_nodo: Node, direccion_puerta: String) -> void:
	var direccion_limpia = direccion_puerta.to_lower().strip_edges()
	var nombre_puerta_buscada = "salida " + direccion_limpia
	var puerta: Node3D = null
	
	var nodos_a_revisar = [cuarto_nodo]
	while nodos_a_revisar.size() > 0:
		var actual = nodos_a_revisar.pop_back()
		if actual.name.to_lower().strip_edges() == nombre_puerta_buscada:
			if actual is Node3D:
				puerta = actual
				break
		nodos_a_revisar.append_array(actual.get_children())

	if puerta != null:
		var pos_puerta = puerta.global_position
		var distancia_seguridad: float = 2.5 
		var desfase = Vector3.ZERO
		
		match direccion_limpia:
			"norte": desfase.z = distancia_seguridad    
			"sur":   desfase.z = -distancia_seguridad 
			"este":  desfase.x = -distancia_seguridad 
			"oeste": desfase.x = distancia_seguridad  
				
		var posicion_final = pos_puerta + desfase
		jugador.set_deferred("global_position", Vector3(posicion_final.x, 0.1, posicion_final.z))
	else:
		jugador.set_deferred("global_position", Vector3(0.0, 0.1, 0.0))

func _on_enemigo_revelado() -> void:
	if not habitacion_bloqueada: activa_modo_combate()

func activa_modo_combate() -> void:
	habitacion_bloqueada = true
	print("🔒 [MUNDO]: ¡Combate iniciado! Puertas cerradas.")

func _on_enemigo_muerto(enemigo_instancia: Node3D = null) -> void:
	if cambiando_habitacion: return
		
	if enemigo_instancia and is_instance_valid(enemigo_instancia):
		var pos_muerte = enemigo_instancia.global_position
		call_deferred("soltar_moneda_enemigo_original", pos_muerte)
		
	cantidad_enemigos_vivos -= 1
	if cantidad_enemigos_vivos <= 0:
		cantidad_enemigos_vivos = 0
		habitacion_bloqueada = false
		if registro_enemigos_habitaciones.has(indice_habitacion_actual):
			registro_enemigos_habitaciones[indice_habitacion_actual]["limpia"] = true
		print("🔓 [MUNDO]: Habitación limpia.")

func _on_arbusto_decorativo_destruido(pos_destruccion: Vector3) -> void:
	if cambiando_habitacion: return
	if randf() <= probabilidad_moneda_arbusto:
		call_deferred("soltar_moneda_enemigo_original", pos_destruccion)

func soltar_moneda_enemigo_original(posicion: Vector3) -> void:
	if room_container.get_child_count() > 0:
		var habitacion_actual = room_container.get_child(0)
		var nueva_moneda = escena_moneda.instantiate() as Node3D
		
		if "valor_moneda" in nueva_moneda:
			var valor_base = randi_range(minimo_monedas_por_enemigo, maximo_monedas_por_enemigo)
			var valor_final = valor_base
			if enemigos_totales_en_sala_actual > 1:
				var factor_reduccion = 1.0 / (1.0 + (enemigos_totales_en_sala_actual - 1) * factor_atenuacion_monedas)
				valor_final = int(clamp(valor_base * factor_reduccion, minimo_monedas_por_enemigo, maximo_monedas_por_enemigo))
			nueva_moneda.valor_moneda = valor_final
		
		habitacion_actual.call_deferred("add_child", nueva_moneda)
		nueva_moneda.set_deferred("global_position", Vector3(posicion.x, 0.6, posicion.z))

func _on_jugador_vida_cambiada() -> void:
	if barra_vida and jugador and "vida_maxima" in jugador and "vida_actual" in jugador:
		barra_vida.max_value = jugador.vida_maxima
		barra_vida.value = jugador.vida_actual

func _on_jugador_cargas_cambiadas(cargas_actuales: int, max_cargas: int) -> void:
	if barra_dash:
		barra_dash.max_value = max_cargas
		barra_dash.value = cargas_actuales
