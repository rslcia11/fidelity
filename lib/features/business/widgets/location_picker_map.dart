// lib/features/business/widgets/location_picker_map.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'dart:io';

class LocationPickerMap extends StatefulWidget {
  final Function(double latitude, double longitude, String address)
  onLocationSelected;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const LocationPickerMap({
    super.key,
    required this.onLocationSelected,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  String _address = '';
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      setState(() {
        _selectedLocation = LatLng(
          widget.initialLatitude!,
          widget.initialLongitude!,
        );
        _address = widget.initialAddress ?? '';
        _searchController.text = _address;
      });
      return;
    }
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Servicios de ubicación desactivados');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación denegados permanentemente');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = newLocation;
      });

      _mapController.move(newLocation, 15.0);
      await _updateAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');

      final defaultLocation = const LatLng(-0.1807, -78.4678); // Quito
      setState(() {
        _selectedLocation = defaultLocation;
      });
      _mapController.move(defaultLocation, 12.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usando ubicación por defecto'),
            backgroundColor: Colors.black54,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAddressFromCoordinates(double lat, double lon) async {
    setState(() => _isLoading = true);
    String? newAddress;

    try {
      // Intento 1: Geocoding Nativo
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        List<String> parts = [];
        if (place.street?.isNotEmpty ?? false) parts.add(place.street!);
        if (place.subLocality?.isNotEmpty ?? false) parts.add(place.subLocality!);
        else if (place.locality?.isNotEmpty ?? false) parts.add(place.locality!);
        if (place.subAdministrativeArea?.isNotEmpty ?? false) parts.add(place.subAdministrativeArea!);
        
        if (parts.isNotEmpty) {
          newAddress = parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint('Error geocoding nativo: $e');
    }

    // Intento 2: Nominatim (OpenStreetMap) de respaldo si el nativo falla o es incompleto
    if (newAddress == null || newAddress.length < 5) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
        final request = await client.getUrl(uri);
        
        // Nominatim requiere User-Agent descriptivo y acepta lenguaje prioritario
        request.headers.set(HttpHeaders.userAgentHeader, 'FidelityApp/1.0 (fidelitysistemadefidelizacion@gmail.com)');
        request.headers.set(HttpHeaders.acceptLanguageHeader, 'es-ES,es;q=0.9');
        
        final response = await request.close();
        
        if (response.statusCode == 200) {
          final content = await response.transform(utf8.decoder).join();
          final data = json.decode(content);
          
          final addressData = data['address'];
          if (addressData != null) {
            final road = addressData['road'] ?? addressData['pedestrian'] ?? '';
            final neighborhood = addressData['neighborhood'] ?? addressData['suburb'] ?? addressData['residential'] ?? '';
            final city = addressData['city'] ?? addressData['town'] ?? addressData['village'] ?? '';
            
            final parts = [road, neighborhood, city].where((s) => s.toString().isNotEmpty).toList();
            if (parts.isNotEmpty) {
              newAddress = parts.join(', ');
            } else {
              newAddress = data['display_name'];
            }
          } else {
            newAddress = data['display_name'];
          }
          
          // Limpiar si es demasiado largo
          if (newAddress != null && newAddress!.length > 100) {
            newAddress = newAddress!.split(',').take(3).join(', ').trim();
          }
        }
      } catch (e) {
        debugPrint('Error geocoding Nominatim: $e');
      }
    }

    setState(() {
      _address = newAddress ?? 'Ubicación: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
      _searchController.text = _address;
      _isLoading = false;
    });

    widget.onLocationSelected(lat, lon, _address);
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    LatLng? newLocation;
    String? newAddress;

    try {
      // Intento 1: Geocoding Nativo
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        newLocation = LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      debugPrint('Error búsqueda nativa: $e');
    }

    // Intento 2: Nominatim Search de respaldo
    if (newLocation == null) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        final uri = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=1&addressdetails=1');
        final request = await client.getUrl(uri);
        
        request.headers.set(HttpHeaders.userAgentHeader, 'FidelityApp/1.0 (fidelitysistemadefidelizacion@gmail.com)');
        request.headers.set(HttpHeaders.acceptLanguageHeader, 'es-ES,es;q=0.9');
        
        final response = await request.close();
        
        if (response.statusCode == 200) {
          final content = await response.transform(utf8.decoder).join();
          final data = json.decode(content);
          if (data is List && data.isNotEmpty) {
            final firstMatch = data[0];
            newLocation = LatLng(
              double.parse(firstMatch['lat']),
              double.parse(firstMatch['lon']),
            );
            
            final addressData = firstMatch['address'];
            if (addressData != null) {
              final road = addressData['road'] ?? addressData['pedestrian'] ?? '';
              final neighborhood = addressData['neighborhood'] ?? addressData['suburb'] ?? addressData['residential'] ?? '';
              final city = addressData['city'] ?? addressData['town'] ?? addressData['village'] ?? '';
              final parts = [road, neighborhood, city].where((s) => s.toString().isNotEmpty).toList();
              newAddress = parts.isNotEmpty ? parts.join(', ') : firstMatch['display_name'];
            } else {
              newAddress = firstMatch['display_name'];
            }
          }
        }
      } catch (e) {
        debugPrint('Error búsqueda Nominatim: $e');
      }
    }

    if (newLocation != null) {
      if (mounted) {
        setState(() {
          _selectedLocation = newLocation;
          _mapController.move(newLocation!, 15.0);
        });
      }
      
      if (newAddress != null) {
        if (mounted) {
          setState(() {
            _address = newAddress!;
            _searchController.text = _address;
          });
        }
        widget.onLocationSelected(newLocation.latitude, newLocation.longitude, _address);
      } else {
        await _updateAddressFromCoordinates(newLocation.latitude, newLocation.longitude);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la dirección')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onMapTapped(TapPosition tap, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
    _updateAddressFromCoordinates(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar dirección...',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: Colors.black,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.04),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _searchAddress,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text(
                    'UBICARME',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          // Mapa
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center:
                        _selectedLocation ?? const LatLng(-0.1807, -78.4678),
                    zoom: 15.0,
                    onTap: _onMapTapped,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.fidelity.app',
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 40.0,
                            height: 40.0,
                            point: _selectedLocation!,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.black,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Dirección seleccionada
          if (_address.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _address,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
