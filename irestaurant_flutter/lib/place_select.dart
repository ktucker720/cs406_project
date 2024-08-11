import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

// A place from Google Places API
class Place {
  String? id;
  String? name;
  String? city;
  Place(Map<String, dynamic> data) {
    id = data["place_id"];
    name = data["name"];
    city = data["city"];
  }
}

// An interactive map for searching and selecting a place
class PlaceSearchMap extends StatefulWidget {
  final Place? initialData;
  final void Function() onCancel;
  final void Function(Place) onSubmit;

  const PlaceSearchMap({super.key, required this.initialData, required this.onCancel, required this.onSubmit});

  @override
  PlaceSearchMapState createState() {
    return PlaceSearchMapState();
  }
}

class PlaceSearchMapState extends State<PlaceSearchMap> {
  Location location = Location();
  final Map<String, Marker> _markers = {};
  double latitude = 0;
  double longitude = 0;
  GoogleMapController? _controller;
  // Start with an initial position in NYC
  final CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(40.730610, -73.935242),
    zoom: 10,
  );

  // Obtain the user's current location
  getCurrentLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    LocationData currentPosition = await location.getLocation();
    latitude = currentPosition.latitude!;
    longitude = currentPosition.longitude!;
    final marker = Marker(
      markerId: const MarkerId('myLocation'),
      position: LatLng(latitude, longitude),
      infoWindow: const InfoWindow(
        title: 'My Location',
      ),
    );
    setState(() {
      _markers['myLocation'] = marker;
      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(latitude, longitude), zoom: 15),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: 400,
          child: GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: true,
            initialCameraPosition: _kGooglePlex,
            markers: _markers.values.toSet(),
            onTap: (LatLng latlng) {
              latitude = latlng.latitude;
              longitude = latlng.longitude;
              final marker = Marker(
                markerId: const MarkerId('myLocation'),
                position: LatLng(latitude, longitude),
                infoWindow: const InfoWindow(
                  title: 'My New Location',
                ),
              );
              setState(() {
                _markers['myLocation'] = marker;
              });
            },
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
              getCurrentLocation();
            },
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 10, 0),
              child: ElevatedButton(
                onPressed: () {
                  //TODO - begin search
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 230, 230, 255)),
                child: const Text('Search')
              )
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
              child: ElevatedButton(
                onPressed: () {
                  widget.onCancel.call();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 230, 230, 255)),
                child: const Text('Cancel')
              )
            ),
          ])
        )
      ]
    );
  }
}