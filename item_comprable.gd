extends Area3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label_info: Label3D = $Label3D 
@onready var sprite_item: Sprite3D = $Sprite3D

var id_item: String = ""
var precio: int = 0
var jugador_en_rango: CharacterBody3D = null
var comprado: bool = false
var datos_item: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Aseguramos visibilidad base al nacer
	if label_info: label_info.text = "" 
	if sprite_item: 
		sprite_item.modulate.a = 1.0
		sprite_item.visible = true

func configurar_articulo(id: String, datos: Dictionary, costo: int) -> void:
	id_item = id
	precio = costo
	comprado = false
	datos_item = datos 
	
	if sprite_item and datos.has("sprite_ruta"):
		var textura = load(datos["sprite_ruta"])
		if textura:
			sprite_item.texture = textura
			sprite_item.pixel_size = 0.002
			sprite_item.modulate.a = 1.0 # Forzamos opacidad total
		else:
			push_warning("No se pudo cargar la textura: " + datos["sprite_ruta"])
	
	# Reproducimos animación solo si existe, si no, garantizamos visibilidad
	if animation_player and animation_player.has_animation("item_spawn"):
		animation_player.play("item_spawn")
	elif sprite_item:
		sprite_item.visible = true

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador") and not comprado:
		jugador_en_rango = body
		if label_info and datos_item.size() > 0:
			label_info.text = datos_item["nombre"] + "\n$" + str(precio) + "\n" + datos_item["desc"]

func _on_body_exited(body: Node3D) -> void:
	if body == jugador_en_rango:
		jugador_en_rango = null
		if label_info and not comprado:
			label_info.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(jugador_en_rango) and event.is_action_pressed("ui_accept") and not comprado:
		intentar_compra()

func intentar_compra() -> void:
	if not is_instance_valid(jugador_en_rango): return
	
	if jugador_en_rango.monedas >= precio:
		if id_item != "pocion" and jugador_en_rango.inventario.size() >= jugador_en_rango.MAX_SLOTS:
			mostrar_mensaje_temporal("¡Inventario Lleno!", 1.5)
			return

		comprado = true
		jugador_en_rango.monedas -= precio
		jugador_en_rango.monedas_cambiadas.emit(jugador_en_rango.monedas)
		jugador_en_rango.equipar_item(id_item)
		
		# Registro en tienda
		var tienda_sala = get_parent()
		if tienda_sala and tienda_sala.has_method("registrar_compra_en_pool"):
			tienda_sala.registrar_compra_en_pool(id_item)

		label_info.text = "¡RECOGIDO!" if precio == 0 else "¡VENDIDO!"
		
		if animation_player: animation_player.stop()
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
		await tween.finished
		queue_free()
	else:
		mostrar_mensaje_temporal("❌ ¡No tienes suficientes monedas!", 1.2)

func mostrar_mensaje_temporal(mensaje: String, tiempo: float) -> void:
	var texto_original = label_info.text
	label_info.text = mensaje
	await get_tree().create_timer(tiempo).timeout
	if is_instance_valid(label_info) and not comprado:
		label_info.text = texto_original
