import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:routenote/src/services/location_parser.dart';

void main() {
  const LocationParser parser = LocationParser();

  group('raw coordinates', () {
    test('parses "lat, lng"', () {
      final ParsedLocation? parsed = parser.parse('30.0444, 31.2357');
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(30.0444, 1e-9));
      expect(parsed.longitude, closeTo(31.2357, 1e-9));
      expect(parsed.name, isNull);
    });

    test('parses signed coordinates separated by a semicolon', () {
      final ParsedLocation? parsed = parser.parse('-33.868800;151.209300');
      expect(parsed!.latitude, closeTo(-33.8688, 1e-9));
      expect(parsed.longitude, closeTo(151.2093, 1e-9));
    });

    test('rejects out-of-range values', () {
      expect(parser.parse('120.0, 31.2357'), isNull);
      expect(parser.parse('30.0444, 200.0'), isNull);
    });

    test('returns null for non-location text', () {
      expect(parser.parse('just some notes'), isNull);
    });
  });

  group('Google Maps links', () {
    test('extracts @lat,lng and the place name', () {
      final ParsedLocation? parsed = parser.parse(
        'https://www.google.com/maps/place/Cairo+Tower/@30.0459,31.2243,17z/data=!3m1',
      );
      expect(parsed!.latitude, closeTo(30.0459, 1e-9));
      expect(parsed.longitude, closeTo(31.2243, 1e-9));
      expect(parsed.name, 'Cairo Tower');
    });

    test('extracts coordinates from ?q=', () {
      final ParsedLocation? parsed = parser.parse(
        'https://maps.google.com/?q=30.0444,31.2357',
      );
      expect(parsed!.latitude, closeTo(30.0444, 1e-9));
      expect(parsed.longitude, closeTo(31.2357, 1e-9));
    });

    test('extracts URL-encoded coordinates from ?query=', () {
      final ParsedLocation? parsed = parser.parse(
        'https://www.google.com/maps/search/?api=1&query=30.0444%2C31.2357',
      );
      expect(parsed!.latitude, closeTo(30.0444, 1e-9));
      expect(parsed.longitude, closeTo(31.2357, 1e-9));
    });

    test('extracts /maps/place/lat,lng', () {
      final ParsedLocation? parsed = parser.parse(
        'https://www.google.com/maps/place/30.0444,31.2357',
      );
      expect(parsed!.latitude, closeTo(30.0444, 1e-9));
      expect(parsed.longitude, closeTo(31.2357, 1e-9));
    });

    test('extracts geo: URIs', () {
      final ParsedLocation? parsed = parser.parse(
        'geo:30.0444,31.2357?q=30.0444,31.2357',
      );
      expect(parsed!.latitude, closeTo(30.0444, 1e-9));
      expect(parsed.longitude, closeTo(31.2357, 1e-9));
    });

    test('finds a coordinate pair embedded in free text', () {
      final ParsedLocation? parsed = parser.parse(
        'Meet me here 30.0444, 31.2357 tomorrow',
      );
      expect(parsed!.latitude, closeTo(30.0444, 1e-9));
    });
  });

  group('short links', () {
    test('recognises short map links', () {
      expect(
        parser.looksLikeShortMapLink('https://maps.app.goo.gl/abcdEFG'),
        isTrue,
      );
      expect(
        parser.looksLikeShortMapLink('https://goo.gl/maps/abcdEFG'),
        isTrue,
      );
      expect(
        parser.looksLikeShortMapLink('https://www.google.com/maps/@1,2,3z'),
        isFalse,
      );
    });

    test('resolves a redirect into coordinates', () async {
      final MockClient client = MockClient((http.Request request) async {
        // 302 to a full Google Maps URL that carries the coordinates.
        return http.Response(
          '',
          302,
          headers: <String, String>{
            'location':
                'https://www.google.com/maps/place/Cairo+Tower/@30.0459,31.2243,17z',
          },
        );
      });

      final ParsedLocation? parsed = await parser.resolveShortLink(
        'https://maps.app.goo.gl/abcdEFG',
        client: client,
      );

      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(30.0459, 1e-9));
      expect(parsed.longitude, closeTo(31.2243, 1e-9));
      expect(parsed.name, 'Cairo Tower');
    });

    test('returns null when the link cannot be resolved', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('nope', 200),
      );

      final ParsedLocation? parsed = await parser.resolveShortLink(
        'https://maps.app.goo.gl/abcdEFG',
        client: client,
      );

      expect(parsed, isNull);
    });
  });

  group('guessName', () {
    test('picks the first non-URL line', () {
      expect(
        parser.guessName('Cairo Tower\nhttps://maps.app.goo.gl/abcdEFG'),
        'Cairo Tower',
      );
    });

    test('returns null when there is only a link', () {
      expect(parser.guessName('https://maps.app.goo.gl/abcdEFG'), isNull);
    });
  });
}
