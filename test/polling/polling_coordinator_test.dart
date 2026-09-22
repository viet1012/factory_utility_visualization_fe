import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:factory_utility_visualization/utility_dashboard/shared/polling/polling_coordinator.dart';
import 'package:factory_utility_visualization/utility_dashboard/shared/polling/polling_scope.dart';

/// Registers a counting task and starts it, matching how production code
/// always pairs `register(...)` with `start(id)`.
int Function() _registerCounter(
  PollingCoordinator coordinator, {
  required String id,
  required PollingScope scope,
  required Duration interval,
  bool runImmediately = true,
  bool autoStart = true,
}) {
  var calls = 0;
  coordinator.register(
    id: id,
    scope: scope,
    interval: interval,
    action: () async => calls++,
    runImmediately: runImmediately,
  );
  if (autoStart) {
    coordinator.start(id);
  }
  return () => calls;
}

void main() {
  group('PollingScope', () {
    test('sub-scope khai bao dung scope cha', () {
      expect(PollingScope.mapMinutely.parent, PollingScope.map);
      expect(PollingScope.mapHourly.parent, PollingScope.map);
      expect(PollingScope.chartsMinutes.parent, PollingScope.charts);

      expect(PollingScope.map.parent, isNull);
      expect(PollingScope.charts.parent, isNull);
      expect(PollingScope.scadaTable.parent, isNull);
      expect(PollingScope.alarms.parent, isNull);
      expect(PollingScope.facilityDetail.parent, isNull);
    });

    test('selfAndAncestors tra ve chinh no roi den cac scope cha', () {
      expect(PollingScope.mapMinutely.selfAndAncestors, [
        PollingScope.mapMinutely,
        PollingScope.map,
      ]);
      expect(PollingScope.chartsMinutes.selfAndAncestors, [
        PollingScope.chartsMinutes,
        PollingScope.charts,
      ]);
      expect(PollingScope.map.selfAndAncestors, [PollingScope.map]);
    });
  });

  group('scope activation', () {
    test('scope con can ca scope cha moi active', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      coordinator.activateScope(PollingScope.mapMinutely);
      expect(
        coordinator.isScopeActive(PollingScope.mapMinutely),
        isFalse,
        reason: 'scope cha chua bat',
      );

      coordinator.activateScope(PollingScope.map);
      expect(coordinator.isScopeActive(PollingScope.mapMinutely), isTrue);
      expect(coordinator.isScopeActive(PollingScope.map), isTrue);
    });

    test('tat scope cha lam scope con khong con hieu luc', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      coordinator.activateScope(PollingScope.map);
      coordinator.activateScope(PollingScope.mapHourly);
      expect(coordinator.isScopeActive(PollingScope.mapHourly), isTrue);

      coordinator.deactivateScope(PollingScope.map);
      expect(coordinator.isScopeActive(PollingScope.mapHourly), isFalse);
    });

    test('co bat cua scope con duoc giu lai khi scope cha tat roi bat lai', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      coordinator.activateScope(PollingScope.map);
      coordinator.activateScope(PollingScope.mapMinutely);

      coordinator.deactivateScope(PollingScope.map);
      expect(coordinator.isScopeActive(PollingScope.mapMinutely), isFalse);

      // Chi bat lai scope cha, khong bat lai scope con.
      coordinator.activateScope(PollingScope.map);
      expect(
        coordinator.isScopeActive(PollingScope.mapMinutely),
        isTrue,
        reason: 'co bat cua scope con phai duoc giu nguyen',
      );
    });

    test('mapMinutely va mapHourly doc lap voi nhau', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      coordinator.activateScope(PollingScope.map);
      coordinator.activateScope(PollingScope.mapMinutely);

      expect(coordinator.isScopeActive(PollingScope.mapMinutely), isTrue);
      expect(coordinator.isScopeActive(PollingScope.mapHourly), isFalse);
    });

    test('chartsMinutes khong bi anh huong boi scope map', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      coordinator.activateScope(PollingScope.map);
      coordinator.activateScope(PollingScope.chartsMinutes);
      expect(
        coordinator.isScopeActive(PollingScope.chartsMinutes),
        isFalse,
        reason: 'charts moi la scope cha, khong phai map',
      );

      coordinator.activateScope(PollingScope.charts);
      expect(coordinator.isScopeActive(PollingScope.chartsMinutes), isTrue);
    });
  });

  group('register va start', () {
    test('register khong tu dong chay task', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final calls = _registerCounter(
          coordinator,
          id: 'map.no-auto-start',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          autoStart: false,
        );

        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 5));
        expect(calls(), 0, reason: 'chua start thi khong duoc chay');

        coordinator.start('map.no-auto-start');
        async.flushMicrotasks();
        expect(calls(), 1);
      });
    });

    test('register trung id bi tu choi', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      coordinator.register(
        id: 'map.dup',
        scope: PollingScope.map,
        interval: const Duration(seconds: 10),
        action: () async {},
      );

      expect(
        () => coordinator.register(
          id: 'map.dup',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          action: () async {},
        ),
        throwsStateError,
      );
    });

    test('register id rong bi tu choi', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      expect(
        () => coordinator.register(
          id: '',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          action: () async {},
        ),
        throwsArgumentError,
      );
    });

    test('interval khong duong bi tu choi', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      expect(
        () => coordinator.register(
          id: 'map.zero',
          scope: PollingScope.map,
          interval: Duration.zero,
          action: () async {},
        ),
        throwsArgumentError,
      );
    });

    test('start voi id chua dang ky nem StateError', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      expect(() => coordinator.start('khong-ton-tai'), throwsStateError);
      expect(() => coordinator.stop('khong-ton-tai'), throwsStateError);
    });

    test('start goi nhieu lan khong tao timer trung', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final calls = _registerCounter(
          coordinator,
          id: 'map.idempotent',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        async.flushMicrotasks();
        expect(calls(), 1);

        coordinator.start('map.idempotent');
        coordinator.start('map.idempotent');
        async.flushMicrotasks();
        expect(calls(), 1, reason: 'start lai khong duoc chay them');

        async.elapse(const Duration(seconds: 10));
        expect(calls(), 2, reason: 'van chi co mot timer');
      });
    });

    test('activateScope goi nhieu lan khong tao tick trung', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final calls = _registerCounter(
          coordinator,
          id: 'map.reactivate',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        async.flushMicrotasks();
        expect(calls(), 1);

        coordinator.activateScope(PollingScope.map);
        coordinator.activateScope(PollingScope.map);
        async.flushMicrotasks();
        expect(calls(), 1, reason: 'activate lai khong duoc chay them');

        async.elapse(const Duration(seconds: 10));
        expect(calls(), 2);
      });
    });
  });

  group('runImmediately', () {
    test('true + start khi scope dang active thi chay ngay mot lan', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final calls = _registerCounter(
          coordinator,
          id: 'map.immediate',
          scope: PollingScope.map,
          interval: const Duration(seconds: 50),
        );

        async.flushMicrotasks();
        expect(calls(), 1, reason: 'phai chay ngay lan dau');

        async.elapse(const Duration(seconds: 50));
        expect(calls(), 2);

        async.elapse(const Duration(seconds: 50));
        expect(calls(), 3);
      });
    });

    test('true + start khi scope chua active thi phai cho', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        final calls = _registerCounter(
          coordinator,
          id: 'map.waiting',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        async.elapse(const Duration(minutes: 5));
        expect(calls(), 0, reason: 'scope chua bat thi khong duoc chay');

        coordinator.activateScope(PollingScope.map);
        async.flushMicrotasks();
        expect(calls(), 1, reason: 'active that su thi chay ngay');
      });
    });

    test('true + activate lap lai khong chay immediate nhieu lan', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        final calls = _registerCounter(
          coordinator,
          id: 'map.once',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        coordinator.activateScope(PollingScope.map);
        async.flushMicrotasks();
        expect(calls(), 1);

        coordinator.activateScope(PollingScope.map);
        coordinator.activateScope(PollingScope.map);
        async.flushMicrotasks();
        expect(calls(), 1, reason: 'khong co lan chay immediate thu hai');
      });
    });

    test('false thi lan chay dau tien phai sau mot interval', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final calls = _registerCounter(
          coordinator,
          id: 'map.delayed',
          scope: PollingScope.map,
          interval: const Duration(seconds: 30),
          runImmediately: false,
        );

        async.flushMicrotasks();
        expect(calls(), 0);

        async.elapse(const Duration(seconds: 29));
        expect(calls(), 0, reason: 'chua du interval');

        async.elapse(const Duration(seconds: 1));
        expect(calls(), 1);

        async.elapse(const Duration(seconds: 30));
        expect(calls(), 2);
      });
    });
  });

  group('khong chay chong nhau', () {
    test('action chua xong thi interval ke tiep khong duoc bat dau', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        var started = 0;
        var completed = 0;
        final gate = Completer<void>();

        coordinator.activateScope(PollingScope.map);
        coordinator.register(
          id: 'map.slow',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          runImmediately: true,
          action: () async {
            started++;
            await gate.future;
            completed++;
          },
        );
        coordinator.start('map.slow');

        async.flushMicrotasks();
        expect(started, 1, reason: 'lan chay dau tien bat dau');
        expect(completed, 0, reason: 'action van dang treo');

        // Interval troi qua nhieu lan trong khi action chua hoan tat.
        async.elapse(const Duration(minutes: 5));
        expect(
          started,
          1,
          reason: 'khong duoc bat dau lan chay thu hai khi lan dau chua xong',
        );

        // Action hoan tat -> moi duoc lap lich tiep.
        gate.complete();
        async.flushMicrotasks();
        expect(completed, 1);

        async.elapse(const Duration(seconds: 10));
        expect(started, 2, reason: 'sau khi xong moi duoc chay tiep');
      });
    });

    test('action lau hon interval van khong bao gio chong nhau', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        var started = 0;
        var concurrent = 0;
        var maxConcurrent = 0;

        coordinator.activateScope(PollingScope.map);
        coordinator.register(
          id: 'map.overlap',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          runImmediately: true,
          action: () async {
            started++;
            concurrent++;
            if (concurrent > maxConcurrent) {
              maxConcurrent = concurrent;
            }
            await Future<void>.delayed(const Duration(seconds: 30));
            concurrent--;
          },
        );
        coordinator.start('map.overlap');

        async.elapse(const Duration(minutes: 5));

        expect(maxConcurrent, 1, reason: 'khong duoc chay chong nhau');
        expect(started, greaterThan(1), reason: 'van phai lap lai theo chu ky');
      });
    });
  });

  group('task theo scope cha con', () {
    test('task o scope con khong chay khi scope cha chua active', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.mapMinutely);
        final calls = _registerCounter(
          coordinator,
          id: 'map.minute',
          scope: PollingScope.mapMinutely,
          interval: const Duration(seconds: 50),
        );

        async.elapse(const Duration(minutes: 5));
        expect(calls(), 0, reason: 'scope cha chua bat');

        coordinator.activateScope(PollingScope.map);
        async.flushMicrotasks();
        expect(calls(), 1, reason: 'du ca cha lan con thi moi chay');
      });
    });

    test('tat scope cha lam task o scope con dung lai', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        coordinator.activateScope(PollingScope.mapMinutely);
        final calls = _registerCounter(
          coordinator,
          id: 'map.minute',
          scope: PollingScope.mapMinutely,
          interval: const Duration(seconds: 50),
        );

        async.flushMicrotasks();
        expect(calls(), 1);

        coordinator.deactivateScope(PollingScope.map);
        async.elapse(const Duration(minutes: 10));
        expect(calls(), 1, reason: 'roi map thi sub-scope phai dung');

        coordinator.activateScope(PollingScope.map);
        async.flushMicrotasks();
        expect(
          calls(),
          2,
          reason: 'co bat cua scope con con nguyen nen chay lai duoc',
        );
      });
    });

    test('doi giua mapMinutely va mapHourly chi chay scope dang bat', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final minute = _registerCounter(
          coordinator,
          id: 'map.minute',
          scope: PollingScope.mapMinutely,
          interval: const Duration(seconds: 50),
        );
        final hourly = _registerCounter(
          coordinator,
          id: 'map.hourly',
          scope: PollingScope.mapHourly,
          interval: const Duration(minutes: 30),
        );

        coordinator.activateScope(PollingScope.mapMinutely);
        async.flushMicrotasks();
        expect(minute(), 1);
        expect(hourly(), 0, reason: 'hourly chua duoc chon');

        // Doi tab: tat minutely, bat hourly.
        coordinator.deactivateScope(PollingScope.mapMinutely);
        coordinator.activateScope(PollingScope.mapHourly);
        async.flushMicrotasks();
        expect(hourly(), 1);

        final minuteAfterSwitch = minute();
        async.elapse(const Duration(minutes: 5));
        expect(
          minute(),
          minuteAfterSwitch,
          reason: 'minute phai dung khi doi sang hourly',
        );
      });
    });

    test('chartsMinutes chay theo scope charts', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        final calls = _registerCounter(
          coordinator,
          id: 'charts.minute-series',
          scope: PollingScope.chartsMinutes,
          interval: const Duration(seconds: 30),
        );

        coordinator.activateScope(PollingScope.chartsMinutes);
        async.elapse(const Duration(minutes: 5));
        expect(calls(), 0, reason: 'thieu scope charts');

        coordinator.activateScope(PollingScope.charts);
        async.flushMicrotasks();
        expect(calls(), 1);

        coordinator.deactivateScope(PollingScope.charts);
        final afterDeactivate = calls();
        async.elapse(const Duration(minutes: 5));
        expect(calls(), afterDeactivate, reason: 'roi charts thi phai dung');
      });
    });
  });

  group('stop', () {
    test('stop huy timer dang cho', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final calls = _registerCounter(
          coordinator,
          id: 'map.stop',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        async.flushMicrotasks();
        expect(calls(), 1);

        coordinator.stop('map.stop');
        async.elapse(const Duration(minutes: 10));
        expect(calls(), 1, reason: 'stop roi thi khong tick nua');
      });
    });

    test('action dang chay xong sau stop thi khong duoc lap lich lai', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        var started = 0;
        final gate = Completer<void>();

        coordinator.activateScope(PollingScope.map);
        coordinator.register(
          id: 'map.inflight',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          runImmediately: true,
          action: () async {
            started++;
            await gate.future;
          },
        );
        coordinator.start('map.inflight');

        async.flushMicrotasks();
        expect(started, 1);

        // Stop trong luc action con dang chay.
        coordinator.stop('map.inflight');
        gate.complete();
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 10));
        expect(
          started,
          1,
          reason: 'action xong sau stop khong duoc chain tiep',
        );
      });
    });

    test('stop roi start lai thi chay tiep duoc', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final calls = _registerCounter(
          coordinator,
          id: 'map.restart',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        async.flushMicrotasks();
        expect(calls(), 1);

        coordinator.stop('map.restart');
        async.elapse(const Duration(minutes: 1));
        expect(calls(), 1);

        coordinator.start('map.restart');
        async.flushMicrotasks();
        expect(calls(), 2, reason: 'start lai thi chay immediate lan nua');
      });
    });
  });

  group('deactivateScope', () {
    test('deactivate huy timer cua task thuoc scope do', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final calls = _registerCounter(
          coordinator,
          id: 'map.deactivate',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        async.flushMicrotasks();
        expect(calls(), 1);

        async.elapse(const Duration(seconds: 10));
        expect(calls(), 2);

        coordinator.deactivateScope(PollingScope.map);
        async.elapse(const Duration(minutes: 10));
        expect(calls(), 2, reason: 'deactivate roi thi khong tick nua');
      });
    });

    test('deactivate khong anh huong task o scope khac', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        coordinator.activateScope(PollingScope.alarms);

        final mapCalls = _registerCounter(
          coordinator,
          id: 'map.task',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );
        final alarmCalls = _registerCounter(
          coordinator,
          id: 'alarms.task',
          scope: PollingScope.alarms,
          interval: const Duration(seconds: 10),
        );

        async.flushMicrotasks();
        expect(mapCalls(), 1);
        expect(alarmCalls(), 1);

        coordinator.deactivateScope(PollingScope.map);
        final mapAfter = mapCalls();
        async.elapse(const Duration(seconds: 30));

        expect(mapCalls(), mapAfter, reason: 'map da tat');
        expect(alarmCalls(), greaterThan(1), reason: 'alarms van chay');
      });
    });

    test('action dang chay xong sau deactivate thi khong lap lich lai', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        var started = 0;
        final gate = Completer<void>();

        coordinator.activateScope(PollingScope.map);
        coordinator.register(
          id: 'map.inflight-deactivate',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          runImmediately: true,
          action: () async {
            started++;
            await gate.future;
          },
        );
        coordinator.start('map.inflight-deactivate');

        async.flushMicrotasks();
        expect(started, 1);

        coordinator.deactivateScope(PollingScope.map);
        gate.complete();
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 10));
        expect(started, 1, reason: 'scope da tat thi khong chain tiep');
      });
    });
  });

  group('unregister', () {
    test('unregister huy timer va chi anh huong dung task do', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final a = _registerCounter(
          coordinator,
          id: 'map.a',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );
        final b = _registerCounter(
          coordinator,
          id: 'map.b',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        async.flushMicrotasks();
        expect(a(), 1);
        expect(b(), 1);

        coordinator.unregister('map.a');
        final aAfter = a();
        async.elapse(const Duration(seconds: 30));

        expect(a(), aAfter, reason: 'task a da bi huy');
        expect(b(), greaterThan(1), reason: 'task b van chay');
      });
    });

    test('task da unregister khong the start lai', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      coordinator.register(
        id: 'map.gone',
        scope: PollingScope.map,
        interval: const Duration(seconds: 10),
        action: () async {},
      );
      coordinator.unregister('map.gone');

      expect(() => coordinator.start('map.gone'), throwsStateError);
    });

    test('unregister id khong ton tai khong nem loi', () {
      final coordinator = PollingCoordinator();
      addTearDown(coordinator.dispose);

      expect(() => coordinator.unregister('khong-ton-tai'), returnsNormally);
    });

    test('unregister roi dang ky lai cung id thi duoc chap nhan', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        coordinator.activateScope(PollingScope.map);
        final first = _registerCounter(
          coordinator,
          id: 'map.recycle',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        async.flushMicrotasks();
        expect(first(), 1);

        coordinator.unregister('map.recycle');

        final second = _registerCounter(
          coordinator,
          id: 'map.recycle',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        async.flushMicrotasks();
        expect(second(), 1, reason: 'task moi chay binh thuong');

        final firstAfter = first();
        async.elapse(const Duration(seconds: 30));
        expect(first(), firstAfter, reason: 'task cu khong song lai');
        expect(second(), greaterThan(1));
      });
    });
  });

  group('dispose', () {
    test('dispose huy moi task', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();

        coordinator.activateScope(PollingScope.map);
        final a = _registerCounter(
          coordinator,
          id: 'map.a',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );
        final b = _registerCounter(
          coordinator,
          id: 'map.b',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
        );

        async.flushMicrotasks();
        expect(a(), 1);
        expect(b(), 1);

        coordinator.dispose();
        async.elapse(const Duration(minutes: 10));

        expect(a(), 1, reason: 'dispose roi thi khong tick nua');
        expect(b(), 1);
        expect(coordinator.isDisposed, isTrue);
      });
    });

    test('dispose hai lan khong nem loi', () {
      final coordinator = PollingCoordinator();
      coordinator.dispose();
      expect(coordinator.dispose, returnsNormally);
      expect(coordinator.isDisposed, isTrue);
    });

    test('sau dispose thi start va activateScope khong hoi sinh task', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();

        final calls = _registerCounter(
          coordinator,
          id: 'map.zombie',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          autoStart: false,
        );

        coordinator.dispose();

        // Sau dispose cac lenh nay la no-op, khong nem loi.
        coordinator.start('map.zombie');
        coordinator.stop('map.zombie');
        coordinator.unregister('map.zombie');
        coordinator.activateScope(PollingScope.map);
        coordinator.deactivateScope(PollingScope.map);

        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 10));
        expect(calls(), 0, reason: 'dispose roi thi khong task nao song lai');
      });
    });

    test('register sau dispose bi tu choi', () {
      final coordinator = PollingCoordinator();
      coordinator.dispose();

      expect(
        () => coordinator.register(
          id: 'map.after-dispose',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          action: () async {},
        ),
        throwsStateError,
      );
    });

    test('action dang chay xong sau dispose thi khong lap lich lai', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();

        var started = 0;
        final gate = Completer<void>();

        coordinator.activateScope(PollingScope.map);
        coordinator.register(
          id: 'map.inflight-dispose',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          runImmediately: true,
          action: () async {
            started++;
            await gate.future;
          },
        );
        coordinator.start('map.inflight-dispose');

        async.flushMicrotasks();
        expect(started, 1);

        coordinator.dispose();
        gate.complete();
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 10));
        expect(started, 1, reason: 'dispose roi thi khong chain tiep');
      });
    });
  });

  group('loi trong action', () {
    test('action nem loi khong lam dung vong lap polling', () {
      fakeAsync((async) {
        final coordinator = PollingCoordinator();
        addTearDown(coordinator.dispose);

        var calls = 0;

        coordinator.activateScope(PollingScope.map);
        coordinator.register(
          id: 'map.failing',
          scope: PollingScope.map,
          interval: const Duration(seconds: 10),
          runImmediately: true,
          action: () async {
            calls++;
            throw StateError('loi gia lap');
          },
        );
        coordinator.start('map.failing');

        async.flushMicrotasks();
        expect(calls, 1);

        async.elapse(const Duration(seconds: 10));
        expect(calls, 2, reason: 'loi phai duoc nuot va van lap lich tiep');

        async.elapse(const Duration(seconds: 10));
        expect(calls, 3);
      });
    });
  });
}
