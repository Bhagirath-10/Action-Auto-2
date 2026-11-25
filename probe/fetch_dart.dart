import 'dart:io';
const tbo = 'https://www.tboholidays.com/imageresource.aspx?img=FbrGPTrju5e/HYusSxssYNGz+r+daGo8+nI8f2/HFw9QwX+47gOd8n0vhhPU+r1v22zr4Z4wuWt7ut0ptMagq1sRyuJt/Vs2zR3nIT9tti5ZOq51mve3701VR1ig3hTEggqmOmw27Q4zR9dkGjQdqgm9jFp0thxKdo3OzevNDDcXH3LBlIl7Sw==';
Future<void> main() async {
  final r = await (await HttpClient().getUrl(Uri.parse(tbo))).close();
  await r.drain<void>();
  print('PROBE2 plain Dart on ${Platform.operatingSystem} -> ${r.statusCode}');
  exit(0);
}
