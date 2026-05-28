import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PlatformService {
  /// Save CSV content to a temp file and share it.
  static Future<String> saveAndShareCsv(
      String fileName, String csvContent, String subject) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvContent);
    await Share.shareXFiles([XFile(file.path)], text: subject);
    return file.path;
  }

  /// Save binary content to a temp file and share it (for Excel etc.).
  static Future<String> saveAndShareBytes(
      String fileName, List<int> bytes, String mimeType, String subject) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: subject);
    return file.path;
  }
}
