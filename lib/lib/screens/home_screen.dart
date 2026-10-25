import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';
import 'rotas_salvas_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _rotaAtual = [];
  List<Map<String, dynamic>> _rotasSalvas = [];
  bool _gravando = false;
  bool _modoManual = false;
  LatLng? _posicaoAtual;
  Stream<Position>? _posicaoStream;

  @override
  void initState() {
    super.initState();
    _carregarRotas();
    _pedirPermissaoLocalizacao();
  }

  Future<void> _pedirPermissaoLocalizacao() async {
    bool permissao = await Geolocator.isLocationServiceEnabled();
    if (!permissao) return;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
      _posicaoStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _posicaoStream?.listen((Position pos) {
        setState(() {
          _posicaoAtual = LatLng(pos.latitude, pos.longitude);
          if (_gravando && !_modoManual) _rotaAtual.add(_posicaoAtual!);
        });
      });
    }
  }

  void _iniciarPararGravacao() {
    setState(() {
      _gravando = !_gravando;
      if (_gravando) _rotaAtual.clear();
    });
  }

  void _alternarModoManual() {
    setState(() {
      _modoManual = !_modoManual;
    });
  }

  void _adicionarPontoManual(LatLng ponto) {
    if (_modoManual && _gravando) {
      setState(() {
        _rotaAtual.add(ponto);
      });
    }
  }

  Future<void> _salvarRota() async {
    if (_rotaAtual.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> lista = prefs.getStringList('rotas') ?? [];
    
    Map<String, dynamic> rota = {
      'nome': 'Rota ${DateTime.now().day}/${DateTime.now().month} ${DateTime.now().hour}:${DateTime.now().minute}',
      'data': DateTime.now().toIso8601String(),
      'pontos': _rotaAtual.map((p) => [p.latitude, p.longitude]).toList(),
    };
    lista.add(jsonEncode(rota));
    await prefs.setStringList('rotas', lista.cast<String>());
    
    setState(() {
      _rotasSalvas.add(rota);
      _gravando = false;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota salva!')));
  }

  Future<void> _carregarRotas() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> lista = prefs.getStringList('rotas') ?? [];
    setState(() {
      _rotasSalvas = lista.map((r) => jsonDecode(r) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _importarGPX() async {
    FilePickerResult? resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['gpx'],
    );
    if (resultado == null) return;

    final conteudo = await resultado.files.first.xFile.readAsString();
    final documento = XmlDocument.parse(conteudo);
    List<LatLng> pontos = [];

    for (final ponto in documento.findAllElements('trkpt')) {
      final lat = double.parse(ponto.getAttribute('lat')!);
      final lon = double.parse(ponto.getAttribute('lon')!);
      pontos.add(LatLng(lat, lon));
    }

    setState(() {
      _rotaAtual = pontos;
      if (pontos.isNotEmpty) _mapController.move(pontos.first, 14);
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${pontos.length} pontos importados!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Rotas Bus'),
        actions: [
          IconButton(icon: const Icon(Icons.folder), tooltip: 'Rotas Salvas',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RotasSalvasScreen()))),
          IconButton(icon: const Icon(Icons.upload_file), tooltip: 'Importar GPX', onPressed: _importarGPX),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _posicaoAtual ?? LatLng(-23.3, -51.2),
              initialZoom: 13,
              onTap: (_, ponto) => _adicionarPontoManual(ponto),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rotasbus.app',
              ),
              if (_rotaAtual.isNotEmpty) PolylineLayer(polylines: [
                Polyline(points: _rotaAtual, color: Colors.blue, strokeWidth: 4),
              ]),
              if (_posicaoAtual != null) MarkerLayer(markers: [
                Marker(point: _posicaoAtual!, child: const Icon(Icons.my_location, color: Colors.red, size: 30)),
              ]),
            ],
          ),
          Positioned(bottom: 90, right: 10,
            child: Column(children: [
              FloatingActionButton.small(heroTag: 'mais',
                onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                child: const Icon(Icons.add)),
              const SizedBox(height: 8),
              FloatingActionButton.small(heroTag: 'menos',
                onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                child: const Icon(Icons.remove)),
            ])),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).cardColor,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _gravando ? Colors.red : Colors.green),
            onPressed: _iniciarPararGravacao,
            icon: Icon(_gravando ? Icons.stop : Icons.play_arrow, color: Colors.white),
            label: Text(_gravando ? 'Parar' : 'Gravar', style: const TextStyle(color: Colors.white)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _modoManual ? Colors.orange : Colors.grey,
            ),
            onPressed: _alternarModoManual,
            icon: const Icon(Icons.touch_app, color: Colors.white),
            label: Text('Manual', style: const TextStyle(color: Colors.white)),
          ),
          ElevatedButton.icon(
            onPressed: _rotaAtual.isNotEmpty ? _salvarRota : null,
            icon: const Icon(Icons.save),
            label: const Text('Salvar'),
          ),
        ]),
      ),
    );
  }
}
