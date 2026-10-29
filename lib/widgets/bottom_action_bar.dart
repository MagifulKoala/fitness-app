import 'package:flutter/material.dart';

/// Full-width primary action (e.g. Save) pinned to the bottom of a screen.
///
/// Use as `Scaffold.bottomNavigationBar`. The [SafeArea] lifts the button
/// above the Android system navigation bar, whose height varies a lot: a thin
/// gesture handle vs. the much taller 3-button bar (back / home / recents).
/// Since Android 15 apps draw edge-to-edge behind that bar, so a button at the
/// end of a scrolling list with only fixed padding ends up hidden under it.
class BottomActionBar extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const BottomActionBar({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onPressed, child: Text(label)),
          ),
        ),
      ),
    );
  }
}
