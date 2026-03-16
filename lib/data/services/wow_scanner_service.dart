import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:path/path.dart' as p;
import 'package:wow_qaddons_manager/domain/models/game_client.dart';

class WoWScannerService {
  /// Ищет все потенциальные исполняемые файлы WoW в директории
  Future<List<GameClient>> scanDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    // 1. Проверяем наличие папки Data или .build.info
    final dataDir = Directory(p.join(path, 'Data'));
    final buildInfo = File(p.join(path, '.build.info'));
    
    final hasData = await dataDir.exists();
    final hasBuildInfo = await buildInfo.exists();

    if (!hasData && !hasBuildInfo) {
      throw Exception('MISSING_DATA');
    }

    final List<File> exes = [];

    try {
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (var entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.exe')) {
          final name = p.basename(entity.path).toLowerCase();
          if (name.contains('wow') || name.contains('world of warcraft')) {
            exes.add(entity);
          }
        }
      }
    } catch (e) {
      throw Exception('READ_ERROR');
    }

    if (exes.isEmpty) {
      throw Exception('MISSING_EXE');
    }

    final List<GameClient> foundClients = [];

    // Для каждого найденного EXE пытаемся определить версию
    for (final exe in exes) {
      final exeName = p.basename(exe.path);
      
      // 1. Пытаемся через .build.info (для современных клиентов)
      GameClient? client = await _parseBuildInfo(path, exeName);
      
      // 2. Если не вышло, пытаемся через метаданные Windows
      if (Platform.isWindows) {
        client ??= await _scanWindowsMetadata(path, exeName);
      }

      // 3. Если все еще не вышло, считаем его Legacy с неизвестной версией
      client ??= GameClient(
          id: DateTime.now().millisecondsSinceEpoch.toString() + exeName,
          path: path,
          version: 'Unknown',
          build: '0',
          type: ClientType.legacy,
          executableName: exeName,
          displayName: exeName.replaceAll('.exe', ''),
        );

      foundClients.add(client);
    }

    return foundClients;
  }

  /// Чтение метаданных из конкретного EXE (Windows)
  Future<GameClient?> _scanWindowsMetadata(String path, String exeName) async {
    final exePath = p.join(path, exeName);
    final file = File(exePath);
    if (!await file.exists()) return null;

    try {
      final lptstrFilename = exePath.toNativeUtf16();
      final dwSize = GetFileVersionInfoSize(lptstrFilename, nullptr);
      
      if (dwSize > 0) {
        final lpData = calloc<Uint8>(dwSize);
        if (GetFileVersionInfo(lptstrFilename, 0, dwSize, lpData) != 0) {
          final lpSubBlock = r'\'.toNativeUtf16();
          final lplpBuffer = calloc<Pointer>();
          final puLen = calloc<Uint32>();

          if (VerQueryValue(lpData, lpSubBlock, lplpBuffer, puLen) != 0) {
            final fileInfo = lplpBuffer.value.cast<VS_FIXEDFILEINFO>().ref;
            
            final version = '${fileInfo.dwFileVersionMS >> 16}.'
                          '${fileInfo.dwFileVersionMS & 0xFFFF}.'
                          '${fileInfo.dwFileVersionLS >> 16}';
            final build = '${fileInfo.dwFileVersionLS & 0xFFFF}';

            free(lptstrFilename);
            free(lpData);
            free(lpSubBlock);
            free(lplpBuffer);
            free(puLen);

            ClientType type = ClientType.legacy;
            if (version.startsWith('11.') || version.startsWith('10.')) type = ClientType.retail;
            if (version.startsWith('3.')) type = ClientType.legacy; // WotLK

            return GameClient(
              id: DateTime.now().millisecondsSinceEpoch.toString() + exeName,
              path: path,
              version: version,
              build: build,
              type: type,
              executableName: exeName,
              displayName: exeName.replaceAll('.exe', ''),
            );
          }
        }
      }
    } catch (e) {
      // Ошибка доступа к Win32 API
    }
    return null;
  }

  /// Парсинг .build.info (Retail/Classic)
  Future<GameClient?> _parseBuildInfo(String path, String exeName) async {
    final file = File(p.join(path, '.build.info'));
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) return null;

      final header = lines[0].split('|');
      final data = lines[1].split('|');

      final versionIdx = header.indexWhere((h) => h.contains('Version'));
      final buildIdx = header.indexWhere((h) => h.contains('Build'));
      final productIdx = header.indexWhere((h) => h.contains('Product'));

      if (versionIdx != -1 && data.length > versionIdx) {
        final version = data[versionIdx];
        final build = buildIdx != -1 ? data[buildIdx] : '0';
        final product = productIdx != -1 ? data[productIdx] : '';

        ClientType type = ClientType.retail;
        if (product.contains('wow_classic')) type = ClientType.classic;
        if (product.contains('ptr')) type = ClientType.ptr;

        return GameClient(
          id: DateTime.now().millisecondsSinceEpoch.toString() + exeName,
          path: path,
          version: version,
          build: build,
          type: type,
          executableName: exeName,
          displayName: 'World of Warcraft ($product)',
        );
      }
    } catch (e) {
      // Ошибка парсинга или доступа
    }
    return null;
  }
}
