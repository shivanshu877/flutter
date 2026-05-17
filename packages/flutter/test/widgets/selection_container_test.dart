// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widgets_app_tester.dart';

void main() {
  Future<void> pumpContainer(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(TestWidgetsApp(home: child));
  }

  testWidgets('updates its registrar and delegate based on the number of selectables', (
    WidgetTester tester,
  ) async {
    final registrar = TestSelectionRegistrar();
    final delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: const Column(
          children: <Widget>[
            Text('column1', textDirection: TextDirection.ltr),
            Text('column2', textDirection: TextDirection.ltr),
            Text('column3', textDirection: TextDirection.ltr),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectables.length, 1);
    expect(delegate.selectables.length, 3);
  });

  testWidgets('disabled container', (WidgetTester tester) async {
    final registrar = TestSelectionRegistrar();
    final delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: const SelectionContainer.disabled(
          child: Column(
            children: <Widget>[
              Text('column1', textDirection: TextDirection.ltr),
              Text('column2', textDirection: TextDirection.ltr),
              Text('column3', textDirection: TextDirection.ltr),
            ],
          ),
        ),
      ),
    );
    expect(registrar.selectables.length, 0);
    expect(delegate.selectables.length, 0);
  });

  testWidgets('Swapping out container delegate does not crash', (WidgetTester tester) async {
    final registrar = TestSelectionRegistrar();
    final delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);
    final childDelegate = TestContainerDelegate();
    addTearDown(childDelegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: Builder(
          builder: (BuildContext context) {
            return SelectionContainer(
              registrar: SelectionContainer.maybeOf(context),
              delegate: childDelegate,
              child: const Text('dummy'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectables.length, 1);
    expect(delegate.value.hasContent, isTrue);

    final newDelegate = TestContainerDelegate();
    addTearDown(newDelegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: Builder(
          builder: (BuildContext context) {
            return SelectionContainer(
              registrar: SelectionContainer.maybeOf(context),
              delegate: newDelegate,
              child: const Text('dummy'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectables.length, 1);
    expect(delegate.value.hasContent, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Can update within one frame', (WidgetTester tester) async {
    final registrar = TestSelectionRegistrar();
    final delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);
    final childDelegate = TestContainerDelegate();
    addTearDown(childDelegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: Builder(
          builder: (BuildContext context) {
            return SelectionContainer(
              registrar: SelectionContainer.maybeOf(context),
              delegate: childDelegate,
              child: const Text('dummy'), // The [Text] widget has an internal [SelectionContainer].
            );
          },
        ),
      ),
    );
    await tester.pump();
    // Should finish update after flushing the micro tasks.
    await tester.idle();
    expect(registrar.selectables.length, 1);
    expect(delegate.value.hasContent, isTrue);
  });

  testWidgets('selection container registers itself if there is a selectable child', (
    WidgetTester tester,
  ) async {
    final registrar = TestSelectionRegistrar();
    final delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);

    await pumpContainer(
      tester,
      SelectionContainer(registrar: registrar, delegate: delegate, child: const Column()),
    );
    expect(registrar.selectables.length, 0);

    await pumpContainer(
      tester,
      SelectionContainer(
        registrar: registrar,
        delegate: delegate,
        child: const Column(children: <Widget>[Text('column1', textDirection: TextDirection.ltr)]),
      ),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectables.length, 1);

    await pumpContainer(
      tester,
      SelectionContainer(registrar: registrar, delegate: delegate, child: const Column()),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectables.length, 0);
  });

  testWidgets('selection container gets registrar from context if not provided', (
    WidgetTester tester,
  ) async {
    final registrar = TestSelectionRegistrar();
    final delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);

    await pumpContainer(
      tester,
      SelectionRegistrarScope(
        registrar: registrar,
        child: SelectionContainer(
          delegate: delegate,
          child: const Column(
            children: <Widget>[Text('column1', textDirection: TextDirection.ltr)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectables.length, 1);
  });

  testWidgets('SelectionContainer unregisters from single-slot registrar when parent type changes', (
    WidgetTester tester,
  ) async {
    // Regression test for https://github.com/flutter/flutter/issues/186459.
    //
    // When the immediate ancestor of a SelectionContainer changes type during a
    // rebuild (e.g. because SelectableRegion conditionally wraps its build output
    // in PlatformSelectableRegionContextMenu when the web context menu is toggled),
    // Flutter deactivates the old subtree before inflating the new one. The old
    // SelectionContainer must unregister in deactivate() so the incoming instance
    // can register without hitting the `_selectable == null` assertion.
    final _TestSingleSlotRegistrar registrar = _TestSingleSlotRegistrar();
    final TestContainerDelegate delegate = TestContainerDelegate();
    addTearDown(delegate.dispose);

    bool useColoredBox = true;
    late StateSetter setState;

    await pumpContainer(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setter) {
          setState = setter;
          final Widget container = SelectionContainer(
            registrar: registrar,
            delegate: delegate,
            child: const Text('hello', textDirection: TextDirection.ltr),
          );
          if (useColoredBox) {
            return ColoredBox(color: const Color(0xFFFFFFFF), child: container);
          }
          return SizedBox(child: container);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(registrar.selectable, isNotNull);

    // Changing the parent type from ColoredBox to SizedBox causes Flutter to
    // deactivate the old ColoredBox→SelectionContainer subtree and inflate a
    // new SizedBox→SelectionContainer. Without the fix, the new
    // SelectionContainer's initState() calls registrar.add() while the old one
    // is still registered, triggering the assertion in _TestSingleSlotRegistrar.
    setState(() { useColoredBox = false; });
    await tester.pump();

    expect(registrar.selectable, isNotNull);
  });
}

class TestContainerDelegate extends MultiSelectableSelectionContainerDelegate {
  @override
  SelectionResult dispatchSelectionEventToChild(Selectable selectable, SelectionEvent event) {
    throw UnimplementedError();
  }

  @override
  void ensureChildUpdated(Selectable selectable) {
    throw UnimplementedError();
  }
}

class TestSelectionRegistrar extends SelectionRegistrar {
  final Set<Selectable> selectables = <Selectable>{};

  @override
  void add(Selectable selectable) => selectables.add(selectable);

  @override
  void remove(Selectable selectable) => selectables.remove(selectable);
}

// A SelectionRegistrar that allows only one registered Selectable at a time,
// mirroring the assertion in SelectableRegionState.add().
class _TestSingleSlotRegistrar extends SelectionRegistrar {
  Selectable? selectable;

  @override
  void add(Selectable s) {
    assert(selectable == null, 'A Selectable is already registered.');
    selectable = s;
  }

  @override
  void remove(Selectable s) {
    assert(selectable == s);
    selectable = null;
  }
}
