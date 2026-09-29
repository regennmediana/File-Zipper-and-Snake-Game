import 'dart:typed_data';
import 'package:archive/archive.dart';

class HuffmanEngine {
  /// Compress bytes using standard ZIP encoder (compatible with WinRAR/7-Zip)
  static List<int> compressToZip(List<int> fileBytes, String originalFileName) {
    final archive = Archive();
    
    // Add file to archive
    final archiveFile = ArchiveFile(originalFileName, fileBytes.length, fileBytes);
    archive.addFile(archiveFile);

    // Encode into ZIP format
    final zipEncoder = ZipEncoder();
    return zipEncoder.encode(archive) ?? [];
  }

  /// Decompress standard ZIP archive bytes
  static List<int> decompress(Uint8List compressedData) {
    final archive = ZipDecoder().decodeBytes(compressedData);
    
    if (archive.files.isEmpty) {
      throw FormatException("The ZIP archive is empty.");
    }

    // Extract content of primary file
    final file = archive.files.first;
    return file.content as List<int>;
  }
}