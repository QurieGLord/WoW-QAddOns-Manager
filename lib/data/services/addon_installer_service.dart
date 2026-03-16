import 'dart:io';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wow_qaddons_manager/domain/models/game_client.dart';
import 'package:wow_qaddons_manager/domain/models/installed_addon.dart';

class AddonInstallerService {
  final Dio _dio = Dio();

  /// Скачивание и установка аддона (Алгоритм Safe Extraction)
  Future<void> installAddon(String downloadUrl, String fileName, GameClient client) async {
    final addonsPath = p.join(client.path, 'Interface', 'AddOns');
    final addonsDir = Directory(addonsPath);
    if (!await addonsDir.exists()) {
      await addonsDir.create(recursive: true);
    }

    // 1. Создаем временную директорию для карантина
    final systemTempDir = await getTemporaryDirectory();
    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempExtractDir = Directory(p.join(systemTempDir.path, 'extract_$uniqueId'));
    await tempExtractDir.create(recursive: true);

    final tempZipPath = p.join(systemTempDir.path, '$uniqueId.zip');

    try {
      // 2. Скачивание
      await _dio.download(downloadUrl, tempZipPath);

      // 3. Распаковка во временную папку
      final bytes = await File(tempZipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filePath = p.join(tempExtractDir.path, file.name);
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }

      // 4. Анализ содержимого карантина
      final entities = await tempExtractDir.list().toList();
      final topLevelFiles = entities.whereType<File>().toList();
      final topLevelDirs = entities.whereType<Directory>().toList();

      final bool hasTocInRoot = topLevelFiles.any((f) => f.path.toLowerCase().endsWith('.toc'));

      // Case A: Плоская структура (файлы .toc в корне архива)
      if (hasTocInRoot) {
        // Создаем папку по имени файла (чистое имя)
        final cleanName = fileName.replaceAll('.zip', '').split('-').first.split('_').first;
        final targetPath = p.join(addonsPath, cleanName);
        await _moveDirectoryContent(tempExtractDir.path, targetPath);
      } 
      // Case B: Одна папка в корне (например, Repo-master)
      else if (topLevelDirs.length == 1 && topLevelFiles.length < 5) {
        final sourceDir = topLevelDirs.first;
        var cleanName = p.basename(sourceDir.path);
        // Очищаем от мусора GitHub/GitLab
        cleanName = cleanName.replaceAll(RegExp(r'-(master|main|v\d+.*)$'), '');
        
        final targetPath = p.join(addonsPath, cleanName);
        await _moveDirectoryContent(sourceDir.path, targetPath);
      }
      // Case C: Аддон-пак (несколько папок в корне)
      else {
        for (var dir in topLevelDirs) {
          // Проверяем, есть ли .toc внутри этой папки, чтобы не тащить мусор
          final hasToc = await Directory(dir.path).list().any((e) => e is File && e.path.toLowerCase().endsWith('.toc'));
          if (hasToc) {
            final targetPath = p.join(addonsPath, p.basename(dir.path));
            await _moveDirectoryContent(dir.path, targetPath);
          }
        }
      }
    } finally {
      // 5. Тотальная очистка
      if (await tempExtractDir.exists()) {
        await tempExtractDir.delete(recursive: true);
      }
      final zFile = File(tempZipPath);
      if (await zFile.exists()) {
        await zFile.delete();
      }
    }
  }

  /// Вспомогательный метод для рекурсивного перемещения содержимого
  Future<void> _moveDirectoryContent(String source, String target) async {
    final sourceDir = Directory(source);
    final targetDir = Directory(target);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    await for (final entity in sourceDir.list(recursive: false)) {
      final name = p.basename(entity.path);
      final newPath = p.join(target, name);

      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _moveDirectoryContent(entity.path, newPath);
      }
    }
  }

  /// Получение списка установленных аддонов (названия из TOC или папок)
  Future<List<InstalledAddon>> getInstalledAddons(GameClient client) async {
    final addonsPath = p.join(client.path, 'Interface', 'AddOns');
    final directory = Directory(addonsPath);

    if (!await directory.exists()) {
      return [];
    }

    final List<InstalledAddon> addons = [];
    final List<FileSystemEntity> entities = await directory.list().toList();

    for (var entity in entities) {
      if (entity is Directory) {
        final folderName = p.basename(entity.path);
        
        // 1. Пропускаем системные папки Blizzard
        if (folderName.startsWith('Blizzard_')) continue;

        // 2. Ищем .toc файл внутри папки (имя файла должно совпадать с папкой или быть единственным .toc)
        final tocFiles = await entity.list().where((f) => f is File && f.path.toLowerCase().endsWith('.toc')).toList();
        
        if (tocFiles.isEmpty) {
          // Если .toc нет - это не аддон (может быть папка core, textures и т.д.)
          continue;
        }

        // 3. Пытаемся прочитать ## Title из .toc файла
        String displayName = folderName;
        try {
          // Ищем .toc с именем папки, если нет - берем первый попавшийся
          final tocFile = tocFiles.firstWhere(
            (f) => p.basename(f.path).toLowerCase() == '${folderName.toLowerCase()}.toc',
            orElse: () => tocFiles.first,
          ) as File;

          final lines = await tocFile.readAsLines();
          for (var line in lines) {
            if (line.trim().startsWith('## Title:')) {
              final title = line.replaceFirst('## Title:', '').trim();
              if (title.isNotEmpty) {
                // Очищаем от цветовых кодов WoW (|cffXXXXXX...|r)
                displayName = title.replaceAll(RegExp(r'\|c[0-9a-fA-F]{8}'), '').replaceAll('|r', '');
                break;
              }
            }
          }
        } catch (e) {
          // В случае ошибки чтения оставляем имя папки
        }

        addons.add(InstalledAddon(folderName: folderName, displayName: displayName));
      }
    }

    return addons..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  /// Удаление папки аддона
  Future<void> deleteAddon(GameClient client, String folderName) async {
    final addonPath = p.join(client.path, 'Interface', 'AddOns', folderName);
    final directory = Directory(addonPath);

    if (await directory.exists()) {
      try {
        await directory.delete(recursive: true);
      } catch (e) {
        throw Exception('DELETE_FAILED: $e');
      }
    } else {
      throw Exception('FOLDER_NOT_FOUND');
    }
  }
}
