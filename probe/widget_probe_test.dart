// Temporary iOS-simulator probe: how do hotel images behave on iOS?
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pillowo/utils/image_helper.dart';
import 'package:pillowo/utils/app_network_image.dart';

class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..badCertificateCallback = (c, h, p) => true;
}

String short(String u) => u.length > 90 ? '${u.substring(0, 90)}...' : u;

Future<List<String>> hotelImageUrls() async {
  final ci = DateTime.now().add(const Duration(days: 14));
  final co = ci.add(const Duration(days: 1));
  String d(DateTime t) => t.toIso8601String().substring(0, 10);
  final c = HttpClient();
  final req = await c.postUrl(Uri.parse('https://pillowo.com/API/hotel/search_hotels_v2.php'));
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Accept', 'application/json');
  req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
  req.write(jsonEncode({
    'location': 'Goa', 'location_search': 'Goa', 'city_code': '119805',
    'checkin': d(ci), 'checkout': d(co), 'page': 1, 'limit': 10, 'rooms': 1,
    'adults': 2, 'children': 0, 'nationality': 'India', 'nationality_code': 'IN',
    'user_id': null, 'room_guests': [{'adults': 2, 'children': 0}], 'load_prices': false,
  }));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('PROBE search API status=${res.statusCode} bytes=${body.length}');
  final data = (jsonDecode(body)['data'] as List?) ?? [];
  return [
    for (final h in data.take(8)) ImageHelper.extractValidImageUrl(h['hotel_images_json']),
  ]..removeWhere((u) => u.isEmpty);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hotel images on iOS', (tester) async {
    HttpOverrides.global = AppHttpOverrides();
    final urls = await tester.runAsync(hotelImageUrls) ?? [];
    urls.add('https://pillowo.com/img/dest_goa.jpg');
    print('PROBE platform=${Platform.operatingSystem} ${Platform.operatingSystemVersion} urls=${urls.length}');

    for (final u in urls) {
      // 1. Raw download with the same HttpClient setup Flutter's NetworkImage uses.
      await tester.runAsync(() async {
        try {
          final c = HttpClient()..autoUncompress = false;
          final r = await (await c.getUrl(Uri.base.resolve(u))).close();
          final bytes = await consolidateHttpClientResponseBytes(r);
          print('PROBE GET ${r.statusCode} type=${r.headers.contentType} len=${bytes.length} ua="${c.userAgent}" uri=${short(Uri.base.resolve(u).toString())}');
          if (r.statusCode == 200) {
            try {
              final codec = await ui.instantiateImageCodec(bytes);
              final f = await codec.getNextFrame();
              print('PROBE DECODE ok ${f.image.width}x${f.image.height}');
            } catch (e) {
              print('PROBE DECODE FAIL $e');
            }
          } else {
            print('PROBE BODY ${String.fromCharCodes(bytes.take(200))}');
          }
        } catch (e) {
          print('PROBE GET ERROR $e');
        }
      });

      // 2. Exactly like the app: Image.network with an errorBuilder.
      Object? err;
      var loaded = false;
      await tester.pumpWidget(MaterialApp(
        home: AppNetworkImage.network(
          u,
          width: 300, height: 180, fit: BoxFit.cover, cacheWidth: 500,
          frameBuilder: (ctx, child, frame, sync) {
            // fixed app code path
            if (frame != null) loaded = true;
            return child;
          },
          errorBuilder: (ctx, e, s) {
            err = e;
            return const SizedBox();
          },
        ),
      ));
      for (var i = 0; i < 60 && !loaded && err == null; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
        await tester.pump();
      }
      print('PROBE WIDGET ${loaded ? 'SHOWN' : (err != null ? 'ERROR $err' : 'TIMEOUT')} ${short(u)}');
    }
  });
}
