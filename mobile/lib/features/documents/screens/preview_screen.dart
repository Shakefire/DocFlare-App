import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../models/document_model.dart';
import 'video_player_screen.dart';

class PreviewScreen extends StatefulWidget {
  final DocumentModel document;

  const PreviewScreen({super.key, required this.document});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  File? _localFile;
  String? _textContent;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final doc = widget.document;
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/preview_${doc.id}_${doc.displayName}';

      final client = ApiClient();
      final file = await client.downloadFile('/documents/${doc.id}/preview', targetPath);

      if (doc.contentType == 'text/plain') {
        _textContent = await file.readAsString();
      }

      if (!mounted) return;
      setState(() {
        _localFile = file;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;

    return Scaffold(
      backgroundColor: doc.isImage ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          doc.displayName,
          style: TextStyle(
            color: doc.isImage ? Colors.white : AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: doc.isImage ? Colors.black : Colors.white,
        elevation: 0,
        leading: BackButton(color: doc.isImage ? Colors.white : AppColors.textPrimary),
        actions: [
          if (_localFile != null)
            IconButton(
              icon: Icon(Icons.open_in_new_rounded, color: doc.isImage ? Colors.white : AppColors.textPrimary),
              tooltip: 'Open with External App',
              onPressed: () => OpenFilex.open(_localFile!.path),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _loadPreview,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final doc = widget.document;

    // 1. Image Preview
    if (doc.isImage && _localFile != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.file(_localFile!),
        ),
      );
    }

    // 2. Text File Preview
    if (doc.contentType == 'text/plain' && _textContent != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          _textContent!,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
        ),
      );
    }

    // 3. Video File Preview
    if (doc.isVideo && _localFile != null) {
      return VideoPlayerScreen(file: _localFile!, title: doc.displayName);
    }

    // 4. PDF or Other Documents
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_rounded, size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              doc.displayName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Document ready for viewing.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
              label: const Text('Open with System Viewer', style: TextStyle(color: Colors.white)),
              onPressed: () {
                if (_localFile != null) {
                  OpenFilex.open(_localFile!.path);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
