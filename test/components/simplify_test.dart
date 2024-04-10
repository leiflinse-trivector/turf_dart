import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:turf/along.dart';
import 'package:turf/area.dart';
import 'package:turf/invariant.dart';
import 'package:turf/meta.dart';
import 'package:turf/simplify.dart';
import 'package:turf_equality/turf_equality.dart';

main() {
  group(
    'simplify in == out',
    () {
      var inDir = Directory('./test/examples/simplify/in');
      for (var file in inDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.geojson')) {
          test(
            file.path,
            () {
              var inSource = file.readAsStringSync();
              var inGeom = GeoJSONObject.fromJson(jsonDecode(inSource));
              var inGeomFeature = inGeom is Feature ? inGeom : null;

              var resultGeom = simplify(
                inGeom,
                tolerance: inGeomFeature?.properties?['tolerance'] ?? 0.01,
                highestQuality:
                    inGeomFeature?.properties?['highQuality'] ?? false,
              );

              // ignore: prefer_interpolation_to_compose_strings
              var outPath = './' +
                  file.uri.pathSegments
                      .sublist(0, file.uri.pathSegments.length - 2)
                      .join('/') +
                  '/out/${file.uri.pathSegments.last}';

              var outSource = File(outPath).readAsStringSync();
              var outGeom = GeoJSONObject.fromJson(jsonDecode(outSource));

              final precision = 0.0001;
              final Set<int> resultIndices = {};
              final Set<int> matchIndices = {};
              final Set<int> outIndices = {};
              featureEach(resultGeom, (rFeature, rFeatureIndex) {
                resultIndices.add(rFeatureIndex);
                featureEach(outGeom, (outFeature, outFeatureIndex) {
                  outIndices.add(outFeatureIndex);
                  if (rFeatureIndex == outFeatureIndex) {
                    matchIndices.add(rFeatureIndex);

                    expect(rFeature.id, outFeature.id);

                    expect(rFeature.properties, equals(outFeature.properties));
                    expect(rFeature.geometry, isNotNull);
                    final inCoords = getCoords(rFeature);
                    final outCoords = getCoords(outFeature);

                    expect(inCoords, hasLength(outCoords.length),
                        reason: '${file.uri}');
                    _coordsEquals(inCoords, outCoords, precision,
                        reason: '${file.uri}');
                  }
                });
              });
              expect(resultIndices, equals(outIndices));
              expect(matchIndices, equals(outIndices));
            },
          );
        }
      }
    },
  );
  test(
    'simplify retains id, properties and bbox',
    () {
      const properties = {"foo": "bar"};
      const id = 12345;
      final bbox = BBox(0, 0, 2, 2);
      final poly = Feature<Polygon>(
        geometry: Polygon(coordinates: [
          [
            Position(0, 0),
            Position(2, 2),
            Position(2, 0),
            Position(0, 0),
          ]
        ]),
        properties: properties,
        bbox: bbox,
        id: id,
      );
      final simple = simplify(poly, tolerance: 0.1) as Feature<Polygon>;

      expect(simple.id, equals(id));
      expect(simple.bbox, equals(bbox));
      expect(simple.properties, equals(properties));
    },
  );
}

List<Position> _roundCoords(List<Position> coords, num precision) {
  return coords
      .map((p) => Position(_round(p.lng, precision), _round(p.lat, precision)))
      .toList();
}

num _round(num value, num precision) {
  return (value / precision).roundToDouble() * precision;
}

/// Expects [inCoords] and [outCoords] to be equal to a given [precision]
///
/// [inCoords] and [outCoords] can be List<Position>, List<List<Position>>
/// or List<List<List<Position>>>
void _coordsEquals(
    List<dynamic> inCoords, List<dynamic> outCoords, num precision,
    {String? reason}) {
  expect(inCoords, hasLength(outCoords.length));
  if (inCoords is List<List<Position>> ||
      inCoords is List<List<List<Position>>>) {
    for (var i = 0; i < inCoords.length; i += 1) {
      _coordsEquals(inCoords[i], outCoords[i], precision, reason: reason);
    }
    return;
  }

  expect(
    _roundCoords(inCoords as List<Position>, precision),
    _roundCoords(outCoords as List<Position>, precision),
    reason: reason,
  );
}
