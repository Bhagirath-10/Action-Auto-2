// Temporary: which way of downloading TBO images works on iOS?
import 'dart:io';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const tbo = 'https://www.tboholidays.com/imageresource.aspx?img=FbrGPTrju5e/HYusSxssYNGz+r+daGo8+nI8f2/HFw9QwX+47gOd8n0vhhPU+r1v22zr4Z4wuWt7ut0ptMagq1sRyuJt/Vs2zR3nIT9tti5ZOq51mve3701VR1ig3hTEggqmOmw27Q4zR9dkGjQdqgm9jFp0thxKdo3OzevNDDcXH3LBlIl7Sw==';

Future<void> dartIo(String label, {String? ua}) async {
  try {
    final c = HttpClient();
    if (ua != null) c.userAgent = ua;
    final r = await (await c.getUrl(Uri.parse(tbo))).close();
    await r.drain<void>();
    print('PROBE2 dart:io $label -> ${r.statusCode}');
  } catch (e) {
    print('PROBE2 dart:io $label -> ERROR $e');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('fetch methods', (tester) async {
    await tester.runAsync(() async {
      await dartIo('default UA');
      await dartIo('UA okhttp', ua: 'okhttp/4.12.0');
      await dartIo('UA CFNetwork', ua: 'Pillowo/38 CFNetwork/3826 Darwin/25.0.0');
      try {
        final client = CupertinoClient.defaultSessionConfiguration();
        final r = await client.get(Uri.parse(tbo));
        print('PROBE2 cupertino_http (iOS URLSession) -> ${r.statusCode} ${r.headers['content-type']} len=${r.bodyBytes.length}');
      } catch (e) {
        print('PROBE2 cupertino_http -> ERROR $e');
      }
      try {
        final r = await http.get(Uri.parse(tbo));
        print('PROBE2 package:http (dart:io) -> ${r.statusCode}');
      } catch (e) {
        print('PROBE2 package:http -> ERROR $e');
      }
    });
  });
}
