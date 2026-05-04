import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider getFileImage(String path) {
  return FileImage(File(path));
}
