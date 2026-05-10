import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:path_provider/path_provider.dart';

Future<String> saveFile(Uint8List bytes, String name, String mime) async {
  late Directory dir;
  if (defaultTargetPlatform == TargetPlatform.android) {
    final d = Directory('/storage/emulated/0/Download');
    dir = await d.exists() ? d : await getApplicationDocumentsDirectory();
  } else {
    dir = await getApplicationDocumentsDirectory();
  }
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  return file.path;
}
