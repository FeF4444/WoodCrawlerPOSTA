extends Node

# Referencias a tus 3 botones de habilidades
@onready var boton_q = $q
@onready var boton_e = $e
@onready var boton_r = $r

# Referencias a tus barras con los nombres correctos
@onready var barra_q = $q/q_CooldownBar
@onready var barra_e = $e/e_CooldownBar
@onready var barra_r = $r/r_CooldownBar

# Tiempos de cooldown para cada habilidad (en segundos)
var cooldown_max_q : float = 4.0
var cooldown_max_e : float = 6.0
var cooldown_max_r : float = 20.0

# Variables para controlar el tiempo actual
var tiempo_q : float = 0.0
var tiempo_e : float = 0.0
var tiempo_r : float = 0.0

func _ready():
	# Inicializar las barras vacías al comenzar
	barra_q.value = 0
	barra_e.value = 0
	barra_r.value = 0
	
	# Activar las habilidades también al hacer clic con el mouse
	boton_q.pressed.connect(usar_q)
	boton_e.pressed.connect(usar_e)
	boton_r.pressed.connect(usar_r)

func _process(delta):
	# --- CONTROL DE LA Q ---
	if tiempo_q > 0:
		tiempo_q -= delta
		barra_q.value = (tiempo_q / cooldown_max_q) * 100
		if tiempo_q <= 0:
			boton_q.disabled = false
			barra_q.value = 0

	# --- CONTROL DE LA E ---
	if tiempo_e > 0:
		tiempo_e -= delta
		barra_e.value = (tiempo_e / cooldown_max_e) * 100
		if tiempo_e <= 0:
			boton_e.disabled = false
			barra_e.value = 0

	# --- CONTROL DE LA R ---
	if tiempo_r > 0:
		tiempo_r -= delta
		barra_r.value = (tiempo_r / cooldown_max_r) * 100
		if tiempo_r <= 0:
			boton_r.disabled = false
			barra_r.value = 0

func _unhandled_input(event):
	# Detectar la tecla Q en el teclado
	if event.is_action_pressed("habilidad_q") and tiempo_q <= 0:
		usar_q()
		
	# Detectar la tecla E en el teclado
	if event.is_action_pressed("habilidad_e") and tiempo_e <= 0:
		usar_e()
		
	# Detectar la tecla R en el teclado
	if event.is_action_pressed("habilidad_r") and tiempo_r <= 0:
		usar_r()

# --- FUNCIONES DE CADA HABILIDAD ---

func usar_q():
	if tiempo_q <= 0:
		tiempo_q = cooldown_max_q
		boton_q.disabled = true
		print("¡Usaste la habilidad q!")
		# Pon aquí el código o animación de tu ataque q

func usar_e():
	if tiempo_e <= 0:
		tiempo_e = cooldown_max_e
		boton_e.disabled = true
		print("¡Usaste la habilidad e!")
		# Pon aquí el código o animación de tu ataque e

func usar_r():
	if tiempo_r <= 0:
		tiempo_r = cooldown_max_r
		boton_r.disabled = true
		print("¡Usaste la habilidad r (Definitiva)!")
		# Pon aquí el código o animación de tu ataque r
