import 'package:flutter/material.dart';
import 'package:tagbox/utils/icon_generator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IconGenerator.generateIcons();
  print('Icons generated successfully!');
} 