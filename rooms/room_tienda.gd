extends Node3D

const PRECIOS_ITEMS = {
	"pocion": 8,       
	"escudo": 15,
	"botas": 10,
	"tobillera": 12,
	"hoja sedienta": 25,       # Corregido: Coincide con el ID de tu base de datos
	"extensor de maniqui": 18, # Corregido: Coincide con el ID de tu base de datos
	"fuelle": 14,
	"falange": 20,
	"bomba": 22,
	"intercambio": 30
}

var escena_articulo: PackedScene = preload("res://item_comprable.tscn")

var ref_jugador: CharacterBody3D = null
var ref_mundo: Node3D = null
var id_sala: int = -1

@onready var marker_1: Marker3D = $Marker3D_Pos1
@onready var marker_2: Marker3D = $Marker3D_Pos2
@onready var marker_3: Marker3D = $Marker3D_Pos3

func inicializar_tienda(player_node: CharacterBody3D, sala_index: int, mundo_node: Node3D) -> void:
	ref_jugador = player_node
	id_sala = sala_index
	ref_mundo = mundo_node
	
	# Forzamos que aparezcan sí o sí las botas y el intercambio primero
	if ref_jugador and "pool_actual" in ref_jugador:
		garantizar_items_obligatorios(ref_jugador.pool_actual)
	
	refrescar_pedestales_tienda()

func garantizar_items_obligatorios(pool: Array) -> void:
	# Si la sala ya existe en el registro del mundo, significa que ya entramos antes.
	# Respetamos el estado guardado (por si el jugador ya compró algo) y no alteramos nada.
	if ref_mundo and ref_mundo.get("registro_tiendas") and ref_mundo.registro_tiendas.has(id_sala):
		return

	# Lista de lo que queremos asegurar en los pedestales 1 y 2.
	# Al meter primero "intercambio" y luego "botas" en el índice 0, las botas quedan en la pos 1.
	var items_obligatorios = ["intercambio", "botas"] 
	
	for item in items_obligatorios:
		if item in pool:
			# Si el objeto ya estaba en el pool aleatorio del jugador, lo removemos de donde esté...
			pool.erase(item)
			# ...y lo inyectamos al principio del todo (índice 0)
			pool.insert(0, item)
		else:
			# Si por alguna razón el pool del jugador no lo traía, lo metemos a la fuerza al inicio
			pool.insert(0, item)

func refrescar_pedestales_tienda() -> void:
	# Limpiamos pedestales viejos
	for m in [marker_1, marker_2, marker_3]:
		if m:
			for hijo in m.get_children():
				hijo.queue_free()

	if ref_jugador == null or !("pool_actual" in ref_jugador):
		return

	var pool = ref_jugador.pool_actual
	var marcadores = [marker_1, marker_2, marker_3]

	# Iteramos por los elementos del pool actual
	for i in range(pool.size()):
		if i >= marcadores.size() or marcadores[i] == null:
			break
			
		var id_item = pool[i]
		
		# Si ya fue comprado o es un espacio vacío, saltamos al siguiente pedestal
		if id_item == "comprado" or id_item.is_empty():
			continue 
			
		# Buscamos el precio en el diccionario. Si no existe, por defecto costará 10.
		var precio = PRECIOS_ITEMS.get(id_item, 10)
		var datos_item = ref_jugador.ITEMS_DB.get(id_item, {"nombre": id_item, "desc": ""})
		
		if escena_articulo:
			var item_instancia = escena_articulo.instantiate()
			marcadores[i].add_child(item_instancia)
			
			if item_instancia.has_method("configurar_articulo"):
				item_instancia.configurar_articulo(id_item, datos_item, precio)

func registrar_compra_en_pool(id_item: String) -> void:
	if ref_jugador == null or !("pool_actual" in ref_jugador) or ref_mundo == null:
		return
		
	var pool = ref_jugador.pool_actual
	var idx = pool.find(id_item)
	
	if idx != -1:
		ref_jugador.pool_actual[idx] = "comprado"
		ref_mundo.registro_tiendas[id_sala] = ref_jugador.pool_actual.duplicate()
