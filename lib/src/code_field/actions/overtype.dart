import 'package:flutter/material.dart';

import '../code_controller.dart';

class ToggleOvertypeIntent extends Intent {
  const ToggleOvertypeIntent();
}

class ToggleOvertypeAction extends Action<ToggleOvertypeIntent> {
  final CodeController controller;

  ToggleOvertypeAction({required this.controller});

  @override
  Object? invoke(ToggleOvertypeIntent intent) {
    controller.toggleOvertypeMode();
    return null;
  }
}
