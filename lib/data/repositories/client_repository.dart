import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';

class ClientRepository {
  static const String _storageKey = 'wow_clients';

  Future<List<GameClient>> getClients() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey);
    if (data == null) return [];
    
    return data.map((item) => GameClient.fromJson(jsonDecode(item))).toList();
  }

  Future<void> saveClient(GameClient client) async {
    final prefs = await SharedPreferences.getInstance();
    final clients = await getClients();
    
    // Предотвращаем дубли по пути
    final index = clients.indexWhere((c) => c.path == client.path);
    if (index != -1) {
      clients[index] = client;
    } else {
      clients.add(client);
    }

    final data = clients.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_storageKey, data);
  }

  Future<void> removeClient(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final clients = await getClients();
    clients.removeWhere((c) => c.id == id);
    
    final data = clients.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_storageKey, data);
  }
}
