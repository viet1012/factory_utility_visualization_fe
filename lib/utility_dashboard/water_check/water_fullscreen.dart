import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Fullscreen cua trinh duyet cho Water check (Fullscreen API).
///
/// Trinh duyet tu thoat fullscreen khi bam Esc va bao qua
/// `fullscreenchange`: nghe bang [listen] de dong bo trang thai UI.
abstract final class BrowserFullscreen {
  static bool get isActive => web.document.fullscreenElement != null;

  /// Bi tu choi (vd khong co user gesture) thi bo qua: UI van an thanh tab.
  static Future<void> enter() async {
    if (isActive) return;
    try {
      await web.document.documentElement?.requestFullscreen().toDart;
    } catch (error) {
      debugPrint('BrowserFullscreen.enter failed: $error');
    }
  }

  static Future<void> exit() async {
    if (!isActive) return;
    try {
      await web.document.exitFullscreen().toDart;
    } catch (error) {
      debugPrint('BrowserFullscreen.exit failed: $error');
    }
  }

  /// Goi [onChange] moi khi vao / thoat fullscreen; tra ve ham huy dang ky.
  static VoidCallback listen(VoidCallback onChange) {
    final listener = ((web.Event _) => onChange()).toJS;
    web.document.addEventListener('fullscreenchange', listener);
    return () => web.document.removeEventListener('fullscreenchange', listener);
  }
}
