import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/features/clients/application/client_use_cases.dart';

class ClientListNotifier extends StateNotifier<List<GameClient>> {
  final LoadClientsUseCase _loadClientsUseCase;
  final SaveClientUseCase _saveClientUseCase;
  final RemoveClientUseCase _removeClientUseCase;
  final RenameClientUseCase _renameClientUseCase;

  ClientListNotifier(
    this._loadClientsUseCase,
    this._saveClientUseCase,
    this._removeClientUseCase,
    this._renameClientUseCase,
  ) : super(const <GameClient>[]) {
    loadClients();
  }

  Future<void> loadClients() async {
    state = await _loadClientsUseCase();
  }

  Future<void> addClient(GameClient client) async {
    await _saveClientUseCase(client);
    await loadClients();
  }

  Future<void> saveClient(GameClient client) async {
    await _saveClientUseCase(client);
    await loadClients();
  }

  Future<void> renameClient(GameClient client) async {
    await _renameClientUseCase(client);
    await loadClients();
  }

  Future<void> removeClient(String id) async {
    await _removeClientUseCase(id);
    await loadClients();
  }
}

final clientListProvider =
    StateNotifierProvider<ClientListNotifier, List<GameClient>>((ref) {
      return ClientListNotifier(
        ref.read(loadClientsUseCaseProvider),
        ref.read(saveClientUseCaseProvider),
        ref.read(removeClientUseCaseProvider),
        ref.read(renameClientUseCaseProvider),
      );
    });
