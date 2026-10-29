import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/widgets/bottom_action_bar.dart';

/// A screen whose body is a long list, with the Save bar pinned at the bottom,
/// on a device whose system nav bar is [navBarHeight] tall.
Widget _screen({required double navBarHeight, VoidCallback? onSave}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        padding: EdgeInsets.only(bottom: navBarHeight),
        viewPadding: EdgeInsets.only(bottom: navBarHeight),
      ),
      child: Scaffold(
        bottomNavigationBar: BottomActionBar(label: 'Save', onPressed: onSave),
        body: ListView(
          children: [for (var i = 0; i < 50; i++) ListTile(title: Text('$i'))],
        ),
      ),
    ),
  );
}

void main() {
  // 0 = no bar, 16 = gesture handle, 48 = 3-button bar (back / home / recents).
  for (final navBar in [0.0, 16.0, 48.0]) {
    testWidgets('Save stays visible above a ${navBar}px system nav bar',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var saved = false;
      await tester.pumpWidget(
          _screen(navBarHeight: navBar, onSave: () => saved = true));

      final button = tester.getRect(find.byType(FilledButton));
      expect(button.bottom, lessThanOrEqualTo(800 - navBar),
          reason: 'button must not overlap the nav bar');

      await tester.tap(find.text('Save'));
      expect(saved, isTrue);
    });
  }

  testWidgets('null onPressed disables the button (e.g. while saving)',
      (tester) async {
    await tester.pumpWidget(_screen(navBarHeight: 48));
    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
  });
}
