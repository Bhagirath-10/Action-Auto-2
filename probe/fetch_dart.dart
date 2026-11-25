import 'dart:io';
const tbo = 'https://www.tboholidays.com/imageresource.aspx?img=FbrGPTrju5e/HYusSxssYNGz+r+daGo8+nI8f2/HFw9QwX+47gOd8n0vhhPU+r1v22zr4Z4wuWt7ut0ptMagq1sRyuJt/Vs2zR3nIT9tti5ZOq51mve3701VR1ig3hTEggqmOmw27Q4zR9dkGjQdqgm9jFp0thxKdo3OzevNDDcXH3LBlIl7Sw==';
Future<void> main() async {
  for (final ua in <String?>['DEFAULT', null, 'Pillowo/1.0.21', 'Pillowo/1.0.21 (iOS)', 'Pillowo/1.0.21 (com.pillowo.app; iOS 26.5)', 'Pillowo', 'okhttp/4.12.0', 'Dart', 'PillowoApp']) {
    final c = HttpClient();
    if (ua != 'DEFAULT') c.userAgent = ua;
    final r = await (await c.getUrl(Uri.parse(tbo))).close();
    await r.drain<void>();
    print('PROBE3 ${Platform.operatingSystem} UA=${ua == 'DEFAULT' ? c.userAgent : ua} -> ${r.statusCode}');
  }
  exit(0);
}
