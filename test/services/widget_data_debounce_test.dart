import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/widget/widget_data_service.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/data/models/tree.dart';

class _RecordingWriter implements WidgetDataWriter {
  final saves = <String, Object>{};
  int saveCalls = 0;
  int refreshes = 0;

  @override
  Future<void> save(String key, Object value) async {
    saveCalls++;
    saves[key] = value;
  }

  @override
  Future<void> refresh() async => refreshes++;
}

void main() {
  test('a burst of updates writes once, with the latest state', () {
    fakeAsync((async) {
      final writer = _RecordingWriter();
      final service = WidgetDataService(writer: writer);
      final tree = Tree(year: 2026);

      // An import emitting the entry list 50 times.
      for (var i = 1; i <= 50; i++) {
        tree.entryCount = i;
        service.scheduleUpdate(
          tree: tree,
          recentEntries: const [],
          showMemoryPreviews: false,
        );
        async.elapse(const Duration(milliseconds: 20));
      }
      expect(writer.refreshes, 0, reason: 'still inside the debounce window');

      async.elapse(const Duration(seconds: 1));
      expect(writer.refreshes, 1);
      expect(writer.saves['entryCount'], 50);
    });
  });

  test('an unchanged payload is not rewritten', () {
    fakeAsync((async) {
      final writer = _RecordingWriter();
      final service = WidgetDataService(writer: writer);
      final tree = Tree(year: 2026)..entryCount = 3;
      final entries = [Entry.line(text: 'a quiet morning')..id = 1];

      void schedule({bool previews = false}) => service.scheduleUpdate(
        tree: tree,
        recentEntries: entries,
        showMemoryPreviews: previews,
      );

      schedule();
      async.elapse(const Duration(seconds: 2));
      expect(writer.refreshes, 1);

      schedule();
      async.elapse(const Duration(seconds: 2));
      expect(writer.refreshes, 1, reason: 'same visible state');

      schedule(previews: true);
      async.elapse(const Duration(seconds: 2));
      expect(writer.refreshes, 2, reason: 'preview opt-in changes payload');
      expect(writer.saves['recentEntries'] as String, contains('quiet'));
    });
  });

  test('flush writes a pending update immediately', () {
    fakeAsync((async) {
      final writer = _RecordingWriter();
      final service = WidgetDataService(writer: writer);
      service.scheduleUpdate(
        tree: null,
        recentEntries: const [],
        showMemoryPreviews: false,
      );
      service.flush();
      async.flushMicrotasks();
      expect(writer.refreshes, 1);
      async.elapse(const Duration(seconds: 2));
      expect(writer.refreshes, 1, reason: 'timer cancelled by flush');
    });
  });
}
