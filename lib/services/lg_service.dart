import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:math' show min, max;
import 'package:path_provider/path_provider.dart';
import 'ssh_service.dart';

class Coordinate {
  final double latitude;
  final double longitude;

  Coordinate(this.latitude, this.longitude);
}

class LGService {
  final SSHService _sshService;
  
  LGService(this._sshService);

  Future<void> setLogo() async {
    try {
      // Read logo from assets
      final logoBytes = await rootBundle.load('assets/logo.png');
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/logo.png';
      
      // Save to temp file
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(logoBytes.buffer.asUint8List());
      
      // Upload to LG
      await _sshService.uploadFile(tempPath, '/var/www/html/logo.png');
      
      // Create and send KML for logo overlay
      final logoKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <ScreenOverlay>
      <name>Logo</name>
      <Icon>
        <href>http://lg1:81/logo.png</href>
      </Icon>
      <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
      <screenXY x="0" y="1" xunits="fraction" yunits="fraction"/>
      <size x="0.3" y="0.2" xunits="fraction" yunits="fraction"/>
    </ScreenOverlay>
  </Document>
</kml>''';
      
      await _sshService.execute('echo \'$logoKml\' > /var/www/html/kml/slave_3.kml');
    } catch (e) {
      throw Exception('Failed to set logo: $e');
    }
  }

  Future<void> clearLogo() async {
    try {
      final blankKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
  </Document>
</kml>''';
      
      await _sshService.execute('echo \'$blankKml\' > /var/www/html/kml/slave_3.kml');
    } catch (e) {
      throw Exception('Failed to clear logo: $e');
    }
  }

  List<Coordinate> _extractCoordinates(String kmlContent) {
    List<Coordinate> coordinates = [];
    
    // Look for <Point> coordinates first (like in kml2.kml)
    final pointMatches = RegExp(r'<Point>\s*<coordinates>([^<]+)</coordinates>', dotAll: true)
        .allMatches(kmlContent);
    
    for (var match in pointMatches) {
      if (match.group(1) != null) {
        final parts = match.group(1)!.trim().split(',');
        if (parts.length >= 2) {
          try {
            final longitude = double.parse(parts[0].trim());
            final latitude = double.parse(parts[1].trim());
            coordinates.add(Coordinate(latitude, longitude));
          } catch (e) {
            print('Error parsing point coordinate: $e');
          }
        }
      }
    }

    // If no Point coordinates found, look for Polygon coordinates (like in kml1.kml)
    if (coordinates.isEmpty) {
      final polygonMatches = RegExp(r'<coordinates>([^<]+)</coordinates>', dotAll: true)
          .allMatches(kmlContent);
      
      for (var match in polygonMatches) {
        if (match.group(1) != null) {
          final coordList = match.group(1)!.trim().split(' ');
          for (var coord in coordList) {
            final parts = coord.split(',');
            if (parts.length >= 2) {
              try {
                final longitude = double.parse(parts[0].trim());
                final latitude = double.parse(parts[1].trim());
                coordinates.add(Coordinate(latitude, longitude));
              } catch (e) {
                print('Error parsing polygon coordinate: $e');
              }
            }
          }
        }
      }
    }

    print('Extracted ${coordinates.length} coordinates');
    return coordinates;
  }

  Coordinate _calculateCenter(List<Coordinate> coordinates) {
    if (coordinates.isEmpty) {
      return Coordinate(0, 0);
    }

    double minLat = coordinates[0].latitude;
    double maxLat = coordinates[0].latitude;
    double minLng = coordinates[0].longitude;
    double maxLng = coordinates[0].longitude;

    for (var coord in coordinates) {
      minLat = min(minLat, coord.latitude);
      maxLat = max(maxLat, coord.latitude);
      minLng = min(minLng, coord.longitude);
      maxLng = max(maxLng, coord.longitude);
    }

    return Coordinate(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );
  }

  Future<void> sendKML(String kmlAsset) async {
    try {
      final kmlContent = await rootBundle.loadString(kmlAsset);
      
      // Extract coordinates and calculate center before file operations
      final coordinates = _extractCoordinates(kmlContent);
      
      if (coordinates.isNotEmpty) {
        final center = _calculateCenter(coordinates);
        
        // Calculate range based on the size of the area
        double maxLat = coordinates.map((c) => c.latitude).reduce(max);
        double minLat = coordinates.map((c) => c.latitude).reduce(min);
        double maxLng = coordinates.map((c) => c.longitude).reduce(max);
        double minLng = coordinates.map((c) => c.longitude).reduce(min);
        
        double latSpread = maxLat - minLat;
        double lngSpread = maxLng - minLng;
        // Use the larger spread to calculate range, convert degrees to meters
        double range = max(latSpread, lngSpread) * 111319.9;
        // Multiply by 2 for better view and ensure minimum range
        range = max(range * 2, 500000);

        print('Flying to: ${center.latitude}, ${center.longitude}, range: $range');
        
        // Clear any existing KML
        await _sshService.execute('> /var/www/html/kmls.txt');
        await _sshService.execute('echo "exittour=true" > /tmp/query.txt');
        await Future.delayed(const Duration(seconds: 1));

        // Send the flyto command
        final flyToCmd = 'echo "flytoview=<LookAt><longitude>${center.longitude}</longitude><latitude>${center.latitude}</latitude><range>$range</range><tilt>60</tilt><heading>0</heading><altitudeMode>relativeToGround</altitudeMode></LookAt>" > /tmp/query.txt';
        await _sshService.execute(flyToCmd);
        await Future.delayed(const Duration(seconds: 3));
      }
      
      // Create a temporary file
      final tempDir = await getTemporaryDirectory();
      final kmlFileName = kmlAsset.split('/').last;
      final tempPath = '${tempDir.path}/$kmlFileName';
      
      // Save KML to temp file
      await File(tempPath).writeAsString(kmlContent);
      
      // Upload KML to LG
      await _sshService.uploadFile(tempPath, '/var/www/html/$kmlFileName');
      
      // Write to kmls.txt
      await _sshService.execute('echo "http://lg1:81/$kmlFileName" > /var/www/html/kmls.txt');
      
      // Ensure content is visible
      await Future.delayed(const Duration(seconds: 1));
      await _sshService.execute('echo "playtour=Refresh" > /tmp/query.txt');
      await Future.delayed(const Duration(milliseconds: 500));
      await _sshService.execute('echo "exittour=true" > /tmp/query.txt');
    } catch (e) {
      print('Error sending KML: $e');
      throw Exception('Failed to send KML: $e');
    }
  }

  Future<void> clearKML() async {
    try {
      await _sshService.execute('> /var/www/html/kmls.txt');
      await _sshService.execute('echo "playtour=Refresh" > /tmp/query.txt');
      await Future.delayed(const Duration(seconds: 1));
      await _sshService.execute('echo "exittour=true" > /tmp/query.txt');
    } catch (e) {
      throw Exception('Failed to clear KML: $e');
    }
  }
}