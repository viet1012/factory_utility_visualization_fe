import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download for in-memory [bytes].
///
/// Uses `package:web` + `dart:js_interop` rather than the deprecated
/// `dart:html`, which is the supported pattern on this Flutter/Dart SDK.
///
/// The bytes are wrapped in a Blob and handed to a synthetic anchor with the
/// `download` attribute, so the current page is never navigated away from and
/// no new tab is opened. The object URL is revoked immediately afterwards to
/// avoid leaking the buffer for the lifetime of the tab.
void downloadBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );

  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);

  anchor.click();

  anchor.remove();

  web.URL.revokeObjectURL(url);
}
