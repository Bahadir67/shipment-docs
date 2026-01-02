import "package:flutter/widgets.dart";

import "app_state.dart";

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState notifier,
    required Widget child
  }) : super(notifier: notifier, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw StateError("AppScope not found in widget tree.");
    }
    return scope.notifier!;
  }
}
