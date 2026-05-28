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
      title: 'NEO-TRACKER GPS',
      theme: ThemeData(
        useMaterial3: true,
        // Paleta Dark Futurista: Grafite, Preto, Ciano Neon e Esmeralda
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F0FF), // Ciano Neon
          secondary: Color(0xFF39FF14), // Verde Neon
          surface: Color(0xFF161B22), // Grafite Escuro
        ),
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
  String _status = 'SISTEMA INICIALIZADO. AGUARDANDO COMANDO...';

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
        _status = 'SISTEMA PAUSADO CONTRA VAZAMENTO DE ENERGIA (BACKGROUND).';
      });
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = 'ALERTA: HARDWARE DE GPS DESLIGADO.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _status = 'ACESSO NEGADO PELO USUÁRIO.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = 'PERMISSÃO BLOQUEADA CRITICAMENTE NO SO.');
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _isLoading = true;
      _status = 'CONECTANDO COM SATÉLITES RECOGNITIVOS...';
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _currentPosition = position;
        _status = 'PING DE POSIÇÃO ÚNICA EFETUADO COM SUCESSO.';
        final time = DateTime.now().toString().substring(11, 19);
        _locationHistory.insert(
          0,
          '[$time] PING -> Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}',
        );
      });
    } catch (e) {
      setState(() => _status = 'FALHA NA CONEXÃO: $e');
    } finally {
      setState(() => _isLoading = false);
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
        _status = 'RASTREAMENTO EM TEMPO REAL INICIADO.';
        _locationHistory.clear();
      });

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 2,
            ),
          ).listen((Position position) {
            setState(() {
              _currentPosition = position;
              final time = DateTime.now().toString().substring(11, 19);

              _locationHistory.insert(
                0,
                '[$time] MOVIMENTO -> Lat: ${position.latitude.toStringAsFixed(4)}',
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
      _status = 'RASTREAMENTO INTERROMPIDO PELO OPERADOR.';
    });
  }

  void _showMapsDialog() {
    if (_currentPosition == null) return;
    final url =
        'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Row(
          children: [
            Icon(Icons.map, color: Color(0xFF00F0FF)),
            SizedBox(width: 10),
            Text(
              'MATRIX LINK',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copie a URL abaixo para ver no mapa:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                  color: Color(0xFF00F0FF),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'FECHAR',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radar, color: Color(0xFF00F0FF)),
            SizedBox(width: 10),
            Text(
              'NEO_TRACKER.SYS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900, // <- Mudado aqui!
                letterSpacing: 1.5,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Console Terminal de Status
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isTracking
                      ? const Color(0xFF39FF14).withOpacity(0.5)
                      : const Color(0xFF00F0FF).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isTracking ? Icons.g_mobiledata : Icons.terminal,
                    color: _isTracking
                        ? const Color(0xFF39FF14)
                        : const Color(0xFF00F0FF),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _isTracking
                            ? const Color(0xFF39FF14)
                            : const Color(0xFF00F0FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Painel Computador de Bordo (Coordenadas)
            Card(
              color: const Color(0xFF161B22),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'TELEMETRIA SATELITAL',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 25),
                    if (_currentPosition != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCyberHUD(
                            'LATITUDE',
                            _currentPosition!.latitude.toStringAsFixed(6),
                            Icons.unfold_more,
                          ),
                          _buildCyberHUD(
                            'LONGITUDE',
                            _currentPosition!.longitude.toStringAsFixed(6),
                            Icons.unfold_less,
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.gps_fixed,
                            size: 14,
                            color: Color(0xFF00F0FF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Precisão: ${_currentPosition!.accuracy.toStringAsFixed(1)} metros',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _showMapsDialog,
                        icon: const Icon(
                          Icons.map,
                          size: 16,
                          color: Color(0xFF00F0FF),
                        ),
                        label: const Text(
                          'Ver URL do Google Maps',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFF00F0FF),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'AGUARDANDO CONEXÃO PRIMÁRIA...',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white30,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Display Grande de Distância
            if (_isTracking) ...[
              Card(
                color: const Color(0xFF00F0FF).withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF00F0FF), width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.directions_walk,
                        size: 32,
                        color: Color(0xFF00F0FF),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DISTÂNCIA ACUMULADA',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00F0FF),
                            ),
                          ),
                          Text(
                            '${_distanceMeters.toStringAsFixed(1)} metros',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            Text(
              'HISTÓRICO DE MOVIMENTAÇÃO',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 5),

            // Painel de Logs de Movimentação
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _locationHistory.isEmpty
                    ? const Center(
                        child: Text(
                          'HISTÓRICO VAZIO',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white12,
                            fontSize: 12,
                          ),
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
                              size: 14,
                              color: Color(0xFF00F0FF),
                            ),
                            title: Text(
                              _locationHistory[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 20),

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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00F0FF),
                            ),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text(
                      'Localizar Já',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF161B22),
                      foregroundColor: const Color(0xFF00F0FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleTracking,
                    icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isTracking ? 'Parar' : 'Rastrear',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: _isTracking
                          ? const Color(0xFFFF0055)
                          : const Color(0xFF39FF14),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  // Componente HUD customizado para as coordenadas ficarem limpas e estilosas
  Widget _buildCyberHUD(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF00F0FF)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
