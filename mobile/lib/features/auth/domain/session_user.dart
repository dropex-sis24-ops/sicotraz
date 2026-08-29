class SessionUser {
  const SessionUser({
    required this.id,
    required this.nombre,
    required this.numeroItem,
    required this.rol,
    required this.debeCambiarPassword,
  });

  final int id;
  final String nombre;
  final String numeroItem;
  final String rol;
  final bool debeCambiarPassword;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    numeroItem: json['numero_item'] as String,
    rol: json['rol'] as String,
    debeCambiarPassword: json['debe_cambiar_password'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'numero_item': numeroItem,
    'rol': rol,
    'debe_cambiar_password': debeCambiarPassword,
  };
}
