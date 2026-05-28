import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const LocationApp());
}

class LocationApp extends StatelessWidget {
  const LocationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aula 12 - GPS Avançado',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const LocationHomePage(),
    );
  }
}

class LocationHomePage extends StatefulWidget {
  const LocationHomePage({super.key});

  @override
  State<LocationHomePage> createState() => _LocationHomePageState();
}

class _LocationHomePageState extends State<LocationHomePage>
    with WidgetsBindingObserver {
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  Position? _lastTrackedPosition;
  double _distanceMeters = 0;
  bool _isLoading = false;
  bool _isTracking = false;
  String _status = 'Pronto para iniciar.';

  // Lista para guardar o histórico de coordenadas por onde o usuário passou
  final List<String> _locationHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isTracking) {
      _stopTracking();
      setState(() {
        _status = 'Tracking pausado (App em segundo plano).';
      });
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _status = 'GPS desligado. Ative nas configurações.';
      });
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _status = 'Permissão de localização negada.';
        });
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _status = 'Permissão negada para sempre. Ative manualmente.';
      });
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _isLoading = true;
      _status = 'Buscando satélites...';
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _currentPosition = position;
        _status = 'Posição atualizada!';
        // Adiciona ao histórico formatado com a hora atual
        final time = DateTime.now().toString().substring(11, 19);
        _locationHistory.insert(
          0,
          '[$time] Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}',
        );
      });
    } catch (e) {
      setState(() {
        _status = 'Erro: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleTracking() async {
    if (_isTracking) {
      _stopTracking();
    } else {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) return;

      setState(() {
        _isTracking = true;
        _distanceMeters = 0;
        _lastTrackedPosition = null;
        _status = 'Rastreamento em tempo real ativo!';
        _locationHistory.clear(); // Limpa histórico ao começar novo tracking
      });

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 2, // Atualiza a cada 2 metros
            ),
          ).listen((Position position) {
            setState(() {
              _currentPosition = position;

              final time = DateTime.now().toString().substring(11, 19);
              _locationHistory.insert(
                0,
                '[$time] Moveu-se para Lat: ${position.latitude.toStringAsFixed(4)}',
              );

              if (_lastTrackedPosition != null) {
                double distance = Geolocator.distanceBetween(
                  _lastTrackedPosition!.latitude,
                  _lastTrackedPosition!.longitude,
                  position.latitude,
                  position.longitude,
                );
                _distanceMeters += distance;
              }
              _lastTrackedPosition = position;
            });
          });
    }
  }

  void _stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    setState(() {
      _isTracking = false;
      _status = 'Tracking finalizado.';
    });
  }

  void _showMapsSnackbar() {
    if (_currentPosition == null) return;
    // URL Corrigida usando a interpolação de string correta do Dart (${var})
    final url =
        'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abrir no Mapa'),
        content: SelectableText(
          url,
          style: const TextStyle(color: Colors.blue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.explore, color: Colors.white),
            SizedBox(width: 10),
            Text('GPS Tracker Novotec'),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status do App com Chip dinâmico
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _isTracking
                    ? Colors.green.shade50
                    : Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isTracking ? Colors.green : Colors.indigo,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isTracking ? Icons.g_mobiledata : Icons.info_outline,
                    color: _isTracking ? Colors.green : Colors.indigo,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isTracking
                            ? Colors.green.shade900
                            : Colors.indigo.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Painel de Exibição das Coordenadas
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'COORDENADAS ATUAIS',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Divider(height: 20),
                    if (_currentPosition != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCoordColumn(
                            'LATITUDE',
                            _currentPosition!.latitude.toStringAsFixed(6),
                            Icons.unfold_more,
                          ),
                          _buildCoordColumn(
                            'LONGITUDE',
                            _currentPosition!.longitude.toStringAsFixed(6),
                            Icons.unfold_less,
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.gps_fixed,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Precisão: ${_currentPosition!.accuracy.toStringAsFixed(1)} metros',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _showMapsSnackbar,
                        icon: const Icon(Icons.map),
                        label: const Text('Ver URL do Google Maps'),
                      ),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Nenhum sinal de GPS recebido ainda.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Painel de Distância / Rastreamento
            if (_isTracking)
              Card(
                color: theme.colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.directions_walk,
                        size: 36,
                        color: Colors.indigo,
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DISTÂNCIA ACUMULADA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          Text(
                            '${_distanceMeters.toStringAsFixed(1)} metros',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 10),
            Text(
              'HISTÓRICO DE MOVIMENTAÇÃO',
              style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey),
            ),

            // Lista com o histórico de passos
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _locationHistory.isEmpty
                    ? const Center(
                        child: Text(
                          'Histórico vazio',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _locationHistory.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.location_searching,
                              size: 16,
                              color: Colors.indigo,
                            ),
                            title: Text(
                              _locationHistory[index],
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          );
                        },
                      ),
              ),
            ),

            // Botões de Comando organizados Lado a Lado
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? null : _getCurrentLocation,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Localizar Já'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleTracking,
                    icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(_isTracking ? 'Parar' : 'Rastrear'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: _isTracking
                          ? Colors.red.shade400
                          : Colors.green.shade400,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para estruturar as colunas de Latitude e Longitude
  Widget _buildCoordColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.indigo),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
