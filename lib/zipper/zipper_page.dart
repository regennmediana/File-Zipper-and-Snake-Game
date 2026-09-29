import 'dart:html' as html; // For Flutter Web downloads
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'huffman_engine.dart';
import 'drive_service.dart';

class HuffmanZipperPage extends StatefulWidget {
  const HuffmanZipperPage({super.key});

  @override
  State<HuffmanZipperPage> createState() => _HuffmanZipperPageState();
}

class _HuffmanZipperPageState extends State<HuffmanZipperPage> {
  final DriveService _driveService = DriveService();

  String? _fileName;
  Uint8List? _fileBytes;
  Uint8List? _processedBytes;
  String _statusMessage = "Select a file or fetch from Google Drive.";
  double? _compressionRatio;
  int _processingTimeMs = 0;

  Future<void> _pickLocalFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _fileName = result.files.single.name;
        _fileBytes = result.files.single.bytes;
        _processedBytes = null;
        _compressionRatio = null;
        _statusMessage = "Loaded $_fileName (${_fileBytes!.length} bytes).";
      });
    }
  }

  Future<void> _pickFromDrive() async {
    try {
      final user = await _driveService.signIn();
      if (user == null) return;

      final files = await _driveService.fetchDriveFiles();
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (ctx) => ListView.builder(
          itemCount: files.length,
          itemBuilder: (ctx, index) {
            final file = files[index];
            return ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(file.name ?? 'Untitled'),
              subtitle: Text(file.size != null ? '${file.size} bytes' : 'Unknown size'),
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _statusMessage = "Downloading ${file.name}...");
                final bytes = await _driveService.downloadFile(file.id!);
                setState(() {
                  _fileName = file.name;
                  _fileBytes = bytes;
                  _processedBytes = null;
                  _statusMessage = "Downloaded ${file.name} (${bytes.length} bytes) from Google Drive.";
                });
              },
            );
          },
        ),
      );
    } catch (e) {
      setState(() => _statusMessage = "Google Drive Error: $e");
    }
  }

void _compressFile() {
  if (_fileBytes == null) return;
  final stopwatch = Stopwatch()..start();
  try {
    final compressed = HuffmanEngine.compressToZip(_fileBytes!, _fileName ?? 'file.txt');
    stopwatch.stop();

    setState(() {
      _processedBytes = Uint8List.fromList(compressed);
      _processingTimeMs = stopwatch.elapsedMilliseconds;
      _statusMessage = "Compressed successfully into ZIP in ${_processingTimeMs}ms!";
    });
  } catch (e) {
    setState(() => _statusMessage = "Compression Error: $e");
  }
}

  void _decompressFile() {
  if (_fileBytes == null) return;
  final stopwatch = Stopwatch()..start();
  try {
    // Call the ZIP decoder instead of custom Huffman decoder
   final decompressed = HuffmanEngine.decompress(_fileBytes!);
    stopwatch.stop();

    setState(() {
      _processedBytes = Uint8List.fromList(decompressed);
      _processingTimeMs = stopwatch.elapsedMilliseconds;
      _statusMessage = "Decompressed successfully in ${_processingTimeMs}ms!";
    });
  } catch (e) {
    setState(() => _statusMessage = "Decompression Error: $e");
  }
}
  

  Future<void> _saveToDesktop() async {
  if (_processedBytes == null || _fileName == null) return;

  final defaultName = _fileName!.endsWith('.zip')
    ? _fileName!.replaceAll('.zip', '_decompressed')
    : '$_fileName.zip';

  if (kIsWeb) {
    // Browser download for Flutter Web
    final blob = html.Blob([_processedBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", defaultName)
      ..click();
    html.Url.revokeObjectUrl(url);

    setState(() {
      _statusMessage = "Downloaded $defaultName to your Downloads folder!";
    });
  } else {
    // Desktop/Mobile native save
    final resultPath = await DriveService.saveFileToLocalDisk(
      bytes: _processedBytes!,
      defaultFileName: defaultName,
    );

    if (resultPath != null) {
      setState(() => _statusMessage = "Saved file successfully!");
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Huffman File Zipper')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.folder_open, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(_fileName ?? "No File Selected", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickLocalFile,
                          icon: const Icon(Icons.file_upload),
                          label: const Text("Local File"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _pickFromDrive,
                          icon: const Icon(Icons.cloud_download),
                          label: const Text("Google Drive"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _fileBytes != null ? _compressFile : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.indigo,
                    ),
                    child: const Text("Compress (.zip)"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _fileBytes != null ? _decompressFile : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.teal,
                    ),
                    child: const Text("Decompress"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              color: Colors.black26,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Result Summary:", style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                    if (_fileBytes != null) Text("Original Size: ${_fileBytes!.length} bytes"),
                    if (_processedBytes != null) ...[
                      Text("Output Size: ${_processedBytes!.length} bytes"),
                      if (_compressionRatio != null)
                        Text(
                          "Space Saved: ${_compressionRatio!.toStringAsFixed(2)}%",
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        ),
                      Text("Time Taken: $_processingTimeMs ms"),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _saveToDesktop,
                        icon: const Icon(Icons.save_alt),
                        label: const Text("Save File to Desktop"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}