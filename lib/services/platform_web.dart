import 'dart:html' as html;
import 'dart:convert';

class PlatformService {
  /// Save CSV content by triggering a browser download.
  static Future<String> saveAndShareCsv(
      String fileName, String csvContent, String subject) async {
    final bytes = utf8.encode(csvContent);
    _triggerDownload(fileName, bytes, 'text/csv;charset=utf-8');
    return fileName;
  }

  /// Save binary content by triggering a browser download.
  static Future<String> saveAndShareBytes(
      String fileName, List<int> bytes, String mimeType, String subject) async {
    _triggerDownload(fileName, bytes, mimeType);
    return fileName;
  }

  static void _triggerDownload(
      String fileName, List<int> bytes, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    // ignore: unused_local_variable
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
