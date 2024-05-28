import 'package:chronosgl/chronosgl.dart';

final Map<int, String> _componentTypes = {
  GL_FLOAT: 'float',
  GL_UNSIGNED_BYTE: 'unsigned byte',
  GL_UNSIGNED_SHORT: 'unsigned short',
  GL_UNSIGNED_INT: 'unsigned int',
  GL_BYTE: 'byte',
  GL_SHORT: 'short',
  GL_INT: 'int',
};

String typeName(int glenum) {
  return _componentTypes[glenum] ?? "glenum 0x{glenum.toRadixString(16)}";
}
