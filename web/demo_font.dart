import 'package:vector_math/vector_math.dart' as VM;

import 'package:chronosgl/chronosgl.dart';

class FontChar {
  FontChar(this.letter, this.w, this.h, this.bits);

  final String letter;
  final int w;
  final int h;
  final String bits;
}

List<VM.Vector2> RenderFontPixelsGlyphs(
    List<int> text, Map<int, FontChar> font, VM.Vector2 origin, double scale) {
  List<VM.Vector2> out = [];
  for (int i = 0; i < text.length; ++i) {
    FontChar fc = font[text[i]]!;

    for (int x = 0; x < fc.w; ++x) {
      for (int y = 0; y < fc.h; ++y) {
        if ("*" != fc.bits[x + y * fc.w]) continue;
        var t =
            VM.Vector2(origin.x + (x + i * fc.w) * scale, origin.y - y * scale);
        out.add(t);
      }
    }
  }
  return out;
}

List<VM.Vector2> RenderFontPixelsString(
    String text, Map<int, FontChar> font, VM.Vector2 origin, double scale) {
  List<int> glyphs = [];
  for (int i = 0; i < text.length; ++i) {
    glyphs.add(text.codeUnitAt(i));
  }
  return RenderFontPixelsGlyphs(glyphs, font, origin, scale);
}

final List<VM.Vector3> _CubeNormals = [
  // Front face
  VM.Vector3(0.0, 0.0, 1.0),
  // Back face
  VM.Vector3(0.0, 0.0, -1.0),
  // Top face
  VM.Vector3(0.0, 1.0, 0.0),
  // Bottom face
  VM.Vector3(0.0, -1.0, 0.0),
// Right face
  VM.Vector3(1.0, 0.0, 0.0),
  // Left face
  VM.Vector3(-1.0, 0.0, 0.0)
];

List<VM.Vector3> _CubeVertices = [
  // Front face
  VM.Vector3(-0.5, -0.5, 0.5),
  VM.Vector3(0.5, -0.5, 0.5),
  VM.Vector3(0.5, 0.5, 0.5),
  VM.Vector3(-0.5, 0.5, 0.5),

  // Back face
  VM.Vector3(-0.5, -0.5, -0.5),
  VM.Vector3(-0.5, 0.5, -0.5),
  VM.Vector3(0.5, 0.5, -0.5),
  VM.Vector3(0.5, -0.5, -0.5),

  // Top face
  VM.Vector3(-0.5, 0.5, -0.5),
  VM.Vector3(-0.5, 0.5, 0.5),
  VM.Vector3(0.5, 0.5, 0.5),
  VM.Vector3(0.5, 0.5, -0.5),

  // Bottom face
  VM.Vector3(0.5, -0.5, 0.5),
  VM.Vector3(-0.5, -0.5, 0.5),
  VM.Vector3(-0.5, -0.5, -0.5),
  VM.Vector3(0.5, -0.5, -0.5),

  // Right face
  VM.Vector3(0.5, -0.5, -0.5),
  VM.Vector3(0.5, 0.5, -0.5),
  VM.Vector3(0.5, 0.5, 0.5),
  VM.Vector3(0.5, -0.5, 0.5),

  // Left face
  VM.Vector3(-0.5, -0.5, -0.5),
  VM.Vector3(-0.5, -0.5, 0.5),
  VM.Vector3(-0.5, 0.5, 0.5),
  VM.Vector3(-0.5, 0.5, -0.5)
];

GeometryBuilder MakeMeshForPixels(List<VM.Vector2> pixels, double scale) {
  var gb = GeometryBuilder();
  gb.EnableAttribute(aNormal);
  for (VM.Vector2 p in pixels) {
    gb.AddFaces4(6);
    for (VM.Vector3 cv in _CubeVertices) {
      var v = VM.Vector3(cv.x * scale + p.x, cv.y * scale + p.y, cv.z * scale);
      gb.AddVertex(v);
    }
    for (VM.Vector3 n in _CubeNormals) {
      gb.AddAttributesVector3(aNormal, [n, n, n, n]);
    }
  }
  return gb;
}
