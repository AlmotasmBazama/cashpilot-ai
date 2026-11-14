import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const _cashPilotForceStopAcceptanceSemanticsRequested = bool.fromEnvironment(
  'CASH_PILOT_AI_FORCE_STOP_ACCEPTANCE_SEMANTICS',
  defaultValue: true,
);

const cashPilotForceStopAcceptanceSemanticsEnabled =
    !kReleaseMode && _cashPilotForceStopAcceptanceSemanticsRequested;

const cashPilotForceStopAcceptanceArabicPrompt =
    'اشرح لي مفهوم التضخم بطريقة بسيطة';

/// Fixed public small-talk input for the resource-ID-only Android acceptance
/// path. It is never included in a semantics identifier or diagnostic event.
const cashPilotAppCheckAcceptanceSmallTalkPrompt = 'how are u';

String? cashPilotForceStopAcceptanceIdentifier(String identifier) {
  return cashPilotForceStopAcceptanceSemanticsEnabled ? identifier : null;
}

Widget cashPilotForceStopAcceptanceSemantics({
  required String identifier,
  required Widget child,
  VoidCallback? onLongPress,
}) {
  if (!cashPilotForceStopAcceptanceSemanticsEnabled) {
    return child;
  }
  final semantics = Semantics(
    container: true,
    enabled: onLongPress == null ? null : true,
    identifier: identifier,
    onLongPress: onLongPress,
    child: child,
  );
  return _CashPilotAcceptanceLongPress(
    onLongPress: onLongPress,
    child: semantics,
  );
}

class _CashPilotAcceptanceLongPress extends StatefulWidget {
  const _CashPilotAcceptanceLongPress({
    required this.onLongPress,
    required this.child,
  });

  final VoidCallback? onLongPress;
  final Widget child;

  @override
  State<_CashPilotAcceptanceLongPress> createState() =>
      _CashPilotAcceptanceLongPressState();
}

class _CashPilotAcceptanceLongPressState
    extends State<_CashPilotAcceptanceLongPress> {
  static const _holdDuration = Duration(milliseconds: 650);
  static const _maxMovementSquared = 18 * 18;
  Timer? _timer;
  int? _pointer;
  Offset? _origin;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start(PointerDownEvent event) {
    if (widget.onLongPress == null || _pointer != null) {
      return;
    }
    _pointer = event.pointer;
    _origin = event.position;
    _timer?.cancel();
    _timer = Timer(_holdDuration, () {
      _timer = null;
      widget.onLongPress?.call();
    });
  }

  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer || _origin == null) {
      return;
    }
    if ((event.position - _origin!).distanceSquared > _maxMovementSquared) {
      _cancel(event);
    }
  }

  void _cancel(PointerEvent event) {
    if (_pointer != event.pointer) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _pointer = null;
    _origin = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _start,
      onPointerMove: _move,
      onPointerUp: _cancel,
      onPointerCancel: _cancel,
      child: widget.child,
    );
  }
}
