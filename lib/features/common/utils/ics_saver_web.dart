import 'dart:html' as html;

Future<void> save(String filename, String icsContent) async {
  final blob = html.Blob([icsContent], 'text/calendar');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}
