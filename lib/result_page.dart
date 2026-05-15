import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'image_processor.dart';

enum ImageViewType { original, grayscale, edges }

class ResultPage extends StatefulWidget {
  const ResultPage({super.key, required this.imageFile});

  final File imageFile;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  Uint8List? _originalBytes;
  Uint8List? _grayscaleBytes;
  Uint8List? _edgeBytes;

  ImageViewType _selectedView = ImageViewType.original;

  double _threshold = 40;
  bool _isProcessing = false;

  String _processingInfo = 'Iniciando processamento...';
  String _dateTimeInfo = '-';
  String _locationInfo = '-';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final bytes = await widget.imageFile.readAsBytes();
    setState(() => _originalBytes = bytes);
    await _registerMetadata();
    await _processImage();
  }

  Future<void> _registerMetadata() async {
    final now = DateTime.now();
    String locationText = 'Localização indisponível';

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        locationText = 'GPS desativado';
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied) {
          locationText = 'Permissão de localização negada';
        } else if (permission == LocationPermission.deniedForever) {
          locationText = 'Permissão negada permanentemente';
        } else {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          locationText =
              'Lat: ${position.latitude.toStringAsFixed(5)}, '
              'Lon: ${position.longitude.toStringAsFixed(5)}';
        }
      }
    } catch (_) {
      locationText = 'Erro ao obter localização';
    }

    if (!mounted) return;
    setState(() {
      _dateTimeInfo = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
      _locationInfo = locationText;
    });
  }

  Future<void> _processImage() async {
    if (_originalBytes == null) return;

    setState(() => _isProcessing = true);

    try {
      final result = await compute(
        processImageIsolate,
        EdgeDetectionInput(
          originalBytes: _originalBytes!,
          threshold: _threshold.toInt(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _grayscaleBytes = result.grayscaleBytes;
        _edgeBytes = result.edgeBytes;
        _processingInfo =
            'Filtro aplicado: tons de cinza + detecção de bordas por '
            'diferença entre pixels vizinhos. '
            'Threshold atual: ${_threshold.toInt()}. '
            'Tamanho: ${result.width}x${result.height}px.';
      });
    } catch (e) {
      _showSnackBar('Erro ao processar imagem: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Uint8List? _getCurrentDisplayedBytes() {
    switch (_selectedView) {
      case ImageViewType.original:
        return _originalBytes;
      case ImageViewType.grayscale:
        return _grayscaleBytes;
      case ImageViewType.edges:
        return _edgeBytes;
    }
  }

  String _getViewLabel() {
    switch (_selectedView) {
      case ImageViewType.original:
        return 'Imagem Original';
      case ImageViewType.grayscale:
        return 'Tons de Cinza';
      case ImageViewType.edges:
        return 'Bordas Detectadas';
    }
  }

  Future<void> _saveProcessedImage() async {
    if (_edgeBytes == null) {
      _showSnackBar('Nenhuma imagem processada para salvar.');
      return;
    }

    try {
      if (Platform.isAndroid) {
        await Permission.photos.request();
        await Permission.storage.request();
      }

      final fileName = 'bordas_${DateTime.now().millisecondsSinceEpoch}';
      final result = await ImageGallerySaverPlus.saveImage(
        _edgeBytes!,
        quality: 100,
        name: fileName,
      );
      _showSnackBar('Imagem salva com sucesso: $result');
    } catch (e) {
      _showSnackBar('Erro ao salvar imagem: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildImageArea() {
    final bytes = _getCurrentDisplayedBytes();

    if (bytes == null) {
      return Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(
        bytes,
        height: 280,
        width: double.infinity,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildSelector() {
    return SegmentedButton<ImageViewType>(
      segments: const [
        ButtonSegment<ImageViewType>(
          value: ImageViewType.original,
          label: Text('Original'),
          icon: Icon(Icons.photo),
        ),
        ButtonSegment<ImageViewType>(
          value: ImageViewType.grayscale,
          label: Text('Cinza'),
          icon: Icon(Icons.filter_b_and_w),
        ),
        ButtonSegment<ImageViewType>(
          value: ImageViewType.edges,
          label: Text('Bordas'),
          icon: Icon(Icons.edgesensor_high),
        ),
      ],
      selected: {_selectedView},
      onSelectionChanged: (value) {
        setState(() => _selectedView = value.first);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _grayscaleBytes != null && _edgeBytes != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageArea(),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _getViewLabel(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            _buildSelector(),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ajuste do threshold',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      value: _threshold,
                      min: 0,
                      max: 255,
                      divisions: 255,
                      label: _threshold.toInt().toString(),
                      onChanged: (_isProcessing || !hasResult)
                          ? null
                          : (value) => setState(() => _threshold = value),
                      onChangeEnd: (_isProcessing || !hasResult)
                          ? null
                          : (_) => _processImage(),
                    ),
                    Text('Threshold atual: ${_threshold.toInt()}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informações do processamento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_processingInfo),
                    const SizedBox(height: 8),
                    Text('Data/Hora: $_dateTimeInfo'),
                    const SizedBox(height: 4),
                    Text('Localização: $_locationInfo'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Nova Captura'),
                ),
                ElevatedButton.icon(
                  onPressed: (_isProcessing || !hasResult)
                      ? null
                      : _processImage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reprocessar'),
                ),
                ElevatedButton.icon(
                  onPressed: hasResult ? _saveProcessedImage : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar Bordas'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
