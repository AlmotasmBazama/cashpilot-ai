import 'package:flutter/widgets.dart';

abstract final class CPSpacing {
  static const none = 0.0;
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  static const bottomNavigationClearance = 96.0;

  static const page = EdgeInsetsDirectional.all(md);
  static const card = EdgeInsetsDirectional.all(md);
  static const field = EdgeInsetsDirectional.fromSTEB(md, sm, md, sm);
  static const section = EdgeInsetsDirectional.fromSTEB(md, lg, md, sm);
}
