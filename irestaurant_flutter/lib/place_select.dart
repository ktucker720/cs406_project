import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

// A place from Google Places API
class Place {
  String? id;
  String? name;
  String? city;
  LatLng? latLng;
  Place(this.id, this.name, this.city, this.latLng);
  Place.fromData(Map<String, dynamic> data) {
    id = data["id"];
    name = data["name"];
    city = data["city"];
    if(data["lat"] != null && data["lng"] != null) {
      latLng = LatLng(data["lat"], data["lng"]);
    }
  }

  Map<String, dynamic> toData() {
    return {
      "id": id,
      "name": name,
      "city": city,
      "lat": latLng?.latitude,
      "lng": latLng?.longitude
    };
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
  final kGoogleApiKey = 'AIzaSyB6iE4pvqiNIi8Hfrcajr9VQJ-8RrkUzzA';
  // Start with an initial position in NYC
  final CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(40.730610, -73.935242),
    zoom: 10,
  );
  String query = "";

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

  // Search for restaurants near current latitude/longitude and
  // make the results selectable markers on the map that submit
  // the associated place data
  void searchPlaces() async {
    var headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': kGoogleApiKey,
      'X-Goog-FieldMask': 'places.id,places.displayName,places.addressComponents,places.location'
    };
    var request = http.Request('POST', Uri.parse('https://places.googleapis.com/v1/places:searchText'));
    // Limit to a few restaurants near the user's current location
    request.body = json.encode({
      "textQuery": query,
      "includedType": "restaurant",
      "maxResultCount": 5,
      "locationBias": {
        "circle": {
        "center": {"latitude": latitude, "longitude": longitude},
        "radius": 1000.0
      }
      }
    });
    request.headers.addAll(headers);
    http.StreamedResponse streamedResponse = await request.send();
    if (streamedResponse.statusCode == 200) {
      var response = await http.Response.fromStream(streamedResponse);
      var result = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        var resultNumber = 1;
        for(var resultItem in result["places"]) {
          String placeId = resultItem["id"];
          String placeName = resultItem["displayName"]["text"];
          String placeCity = "";
          // Extract the city (type is 'locality')
          for(var addressComponent in resultItem["addressComponents"]) {
            if(addressComponent["types"].contains("locality")) {
              placeCity = addressComponent["shortText"];
              break;
            }
          }
          LatLng placeLatLng = LatLng(resultItem["location"]["latitude"], resultItem["location"]["longitude"]);
          final place = Place(placeId, placeName, placeCity, placeLatLng);
          // Selecting the marker (or its info) results in the place being selected
          _markers["result${resultNumber++}"] = Marker(
            markerId: MarkerId(place.id!),
            position: LatLng(place.latLng!.latitude, place.latLng!.longitude),
            consumeTapEvents: true,
            onTap: () {
              widget.onSubmit(place);
            },
            infoWindow: InfoWindow(
              title: place.name,
              snippet: place.city,
              onTap: () {
                widget.onSubmit(place);
              },
            )
          );
        }

      });
    } else {
      // TODO handle error better
      print(streamedResponse.reasonPhrase);
    } 
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
              padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
              child: SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (String s) {
                    query = s;
                  },
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    labelText: 'Name Search',
                  ),
                )
              )
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
              child: ElevatedButton(
                onPressed: searchPlaces,
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