enum ClientType {
  retail,
  classic,
  ptr,
  legacy,
  unknown,
}

class GameClient {
  final String id;
  final String path;
  final String version;
  final String build;
  final ClientType type;
  final String? executableName;
  final String? displayName;

  GameClient({
    required this.id,
    required this.path,
    required this.version,
    required this.build,
    required this.type,
    this.executableName,
    this.displayName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'version': version,
    'build': build,
    'type': type.name,
    'executableName': executableName,
    'displayName': displayName,
  };

  factory GameClient.fromJson(Map<String, dynamic> json) => GameClient(
    id: json['id'],
    path: json['path'],
    version: json['version'],
    build: json['build'],
    type: ClientType.values.firstWhere((e) => e.name == json['type']),
    executableName: json['executableName'],
    displayName: json['displayName'],
  );

  GameClient copyWith({String? displayName}) {
    return GameClient(
      id: id,
      path: path,
      version: version,
      build: build,
      type: type,
      executableName: executableName,
      displayName: displayName ?? this.displayName,
    );
  }
}
