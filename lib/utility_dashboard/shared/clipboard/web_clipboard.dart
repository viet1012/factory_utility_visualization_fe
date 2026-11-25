import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Copy [text] vao clipboard, chay duoc ca khi app mo bang HTTP qua IP LAN.
///
/// Tu Flutter 3.38, `Clipboard.setData` tren web chi dung
/// `navigator.clipboard` (Clipboard API) va bo fallback cu. API nay chi co
/// trong secure context (HTTPS / localhost), nen khi mo bang
/// `http://192.168.x.x` thi `Clipboard.setData` nem `PlatformException`
/// (copy_fail) va khong copy duoc gi.
///
/// Fallback: textarea an + `document.execCommand('copy')`, van chay o
/// context khong secure. Phai goi trong handler cua thao tac nguoi dung
/// (vd onPressed) va truoc bat ky `await` nao, de con user activation.
///
/// Tra ve `true` neu copy thanh cong.
Future<bool> copyTextToClipboard(String text) async {
  if (!web.window.isSecureContext) return _execCommandCopy(text);

  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } catch (_) {
    // Vd trinh duyet chan quyen clipboard: thu cach cu.
    return _execCommandCopy(text);
  }
}

bool _execCommandCopy(String text) {
  final textarea = web.HTMLTextAreaElement()
    ..value = text
    ..readOnly = true;
  textarea.style
    ..position = 'fixed'
    ..top = '0'
    ..left = '0'
    ..width = '1px'
    ..height = '1px'
    ..opacity = '0';

  final body = web.document.body;
  if (body == null) return false;
  body.appendChild(textarea);
  try {
    textarea
      ..focus()
      ..select();
    return web.document.execCommand('copy');
  } catch (_) {
    return false;
  } finally {
    textarea.remove();
  }
}
