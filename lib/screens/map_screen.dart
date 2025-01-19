import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/exam.dart';
import '../utils/google_map_helper.dart';

class MapScreen extends StatefulWidget {
  final List<Exam> exams;

  MapScreen({required this.exams});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  GoogleMapHelper mapHelper = GoogleMapHelper("AIzaSyCqOT_qz7T9FHP8DvFBweaIg3RURoKMhlo");

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _initializeMarkers();
  }

  void _initializeMarkers() {
    setState(() {
      _markers.addAll(widget.exams.map((exam) {
        return Marker(
          markerId: MarkerId(exam.subject),
          position: LatLng(exam.latitude, exam.longitude),
          infoWindow: InfoWindow(
            title: exam.subject,
            snippet: exam.location,
          ),
          onTap: () {
            _showRouteToLocation(LatLng(exam.latitude, exam.longitude));
          },
        );
      }).toSet());
    });
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location services are disabled. Please enable them.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permissions are permanently denied.')),
      );
      return;
    }
  }

  Future<LatLng> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return LatLng(position.latitude, position.longitude);
  }

  Future<void> _showRouteToLocation(LatLng destination) async {
    LatLng currentLocation = await _getCurrentLocation();

    try {
      Map<String, dynamic> directions = await mapHelper.getDirections(currentLocation, destination);

      String polyline = directions['routes'][0]['overview_polyline']['points'];
      List<LatLng> routePoints = mapHelper.decodePolyline(polyline);

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: routePoints,
        ));
      });

      LatLngBounds bounds = _calculateBounds(currentLocation, destination);
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } catch (e) {
      print("Error fetching directions: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch route')),
      );
    }
  }

  LatLngBounds _calculateBounds(LatLng point1, LatLng point2) {
    double southWestLat = (point1.latitude < point2.latitude) ? point1.latitude : point2.latitude;
    double southWestLng = (point1.longitude < point2.longitude) ? point1.longitude : point2.longitude;
    double northEastLat = (point1.latitude > point2.latitude) ? point1.latitude : point2.latitude;
    double northEastLng = (point1.longitude > point2.longitude) ? point1.longitude : point2.longitude;

    return LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
  }

  Future<void> _getPlaceDetails(LatLng location) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${location.latitude},${location.longitude}&radius=50&key=YOUR_API_KEY';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'].isNotEmpty) {
          final place = data['results'][0];
          final LatLng placeLocation = LatLng(
            place['geometry']['location']['lat'],
            place['geometry']['location']['lng'],
          );

          setState(() {
            _markers.add(Marker(
              markerId: MarkerId(place['name']),
              position: placeLocation,
              infoWindow: InfoWindow(
                title: place['name'],
                snippet: place['vicinity'],
                onTap: () => _showRouteToLocation(placeLocation),
              ),
            ));
          });
        }
      } else {
        print("Failed to fetch place details: ${response.body}");
      }
    } catch (e) {
      print("Error fetching place details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Exam Locations')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.exams.isNotEmpty
              ? LatLng(widget.exams[0].latitude, widget.exams[0].longitude)
              : LatLng(41.9981, 21.4254),
          zoom: 12,
        ),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
        onTap: (LatLng position) {
          _getPlaceDetails(position);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          LatLng currentLocation = await _getCurrentLocation();
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(currentLocation, 15));

          setState(() {
            _markers.add(
              Marker(
                markerId: MarkerId("current_location"),
                position: currentLocation,
                infoWindow: InfoWindow(
                  title: "Current Location",
                ),
              ),
            );
          });
        },
        child: Icon(Icons.my_location),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
