extends Button

# Referencia a la barra de cooldown
@onready var cooldown_bar = $CooldownBar

# Configuración de la habilidad
var tiempo_cooldown : float = 5.0  # Duración en segundos
var en_cooldown : bool = false
var tiempo_restante : float = 0.0

func _ready():
	# La barra inicia vacía/oculta
	cooldown_bar.value = 0
	# Conectar el clic del botón
	pressed.connect(_on_habilidad_pressed)

func _process(delta):
	if en_cooldown:
		# Restar el tiempo que pasa en cada fotograma
		tiempo_restante -= delta
		
		# Calcular el porcentaje para la barra (de 0 a 100)
		cooldown_bar.value = (tiempo_restante / tiempo_cooldown) * 100
		
		if tiempo_restante <= 0:
			# El cooldown terminó
			en_cooldown = false
			disabled = false       # Reactivar el botón
			cooldown_bar.value = 0 # Vaciar la barra

func _on_habilidad_pressed():
	if not en_cooldown:
		# Activar el cooldown
		en_cooldown = true
		disabled = true # Desactiva el botón para que no lo presionen otra vez
		tiempo_restante = tiempo_cooldown
		
		# Aquí ejecutas tu habilidad (animaciones, daño, etc.)
		print("¡Habilidad usada!")
