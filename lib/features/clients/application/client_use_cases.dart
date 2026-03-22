import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wow_qaddons_manager/app/providers/service_providers.dart';
import 'package:wow_qaddons_manager/core/services/file_system_service.dart';
import 'package:wow_qaddons_manager/data/repositories/client_repository.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';

class LoadClientsUseCase {
  final ClientRepository _repository;

  const LoadClientsUseCase(this._repository);

  Future<List<GameClient>> call() {
    return _repository.getClients();
  }
}

class SaveClientUseCase {
  final ClientRepository _repository;

  const SaveClientUseCase(this._repository);

  Future<void> call(GameClient client) {
    return _repository.saveClient(client);
  }
}

class RemoveClientUseCase {
  final ClientRepository _repository;

  const RemoveClientUseCase(this._repository);

  Future<void> call(String id) {
    return _repository.removeClient(id);
  }
}

class ScanWowClientsUseCase {
  final FileSystemService _fileSystemService;

  const ScanWowClientsUseCase(this._fileSystemService);

  Future<List<GameClient>> call(String path) {
    return _fileSystemService.scanWowClients(path);
  }
}

class RenameClientUseCase {
  final ClientRepository _repository;

  const RenameClientUseCase(this._repository);

  Future<void> call(GameClient client) {
    return _repository.saveClient(client);
  }
}

class LaunchGameUseCase {
  final FileSystemService _fileSystemService;

  const LaunchGameUseCase(this._fileSystemService);

  Future<void> call(GameClient client) {
    return _fileSystemService.launchGameClient(client);
  }
}

final loadClientsUseCaseProvider = Provider<LoadClientsUseCase>((ref) {
  return LoadClientsUseCase(ref.read(clientRepositoryProvider));
});

final saveClientUseCaseProvider = Provider<SaveClientUseCase>((ref) {
  return SaveClientUseCase(ref.read(clientRepositoryProvider));
});

final removeClientUseCaseProvider = Provider<RemoveClientUseCase>((ref) {
  return RemoveClientUseCase(ref.read(clientRepositoryProvider));
});

final scanWowClientsUseCaseProvider = Provider<ScanWowClientsUseCase>((ref) {
  return ScanWowClientsUseCase(ref.read(fileSystemServiceProvider));
});

final renameClientUseCaseProvider = Provider<RenameClientUseCase>((ref) {
  return RenameClientUseCase(ref.read(clientRepositoryProvider));
});

final launchGameUseCaseProvider = Provider<LaunchGameUseCase>((ref) {
  return LaunchGameUseCase(ref.read(fileSystemServiceProvider));
});
