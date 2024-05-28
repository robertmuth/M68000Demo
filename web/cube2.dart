import 'dart:html' as HTML;

import 'package:chronosgl/chronosgl.dart';
import 'demo_section.dart';
import 'package:vector_math/vector_math.dart' as VM;

import 'effects.dart' as effects;

final ShaderObject vertexShader = ShaderObject("TexturedVertexBoring")
  ..AddAttributeVars([aPosition, aTexUV])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..AddVaryingVars([vTexUV])
  ..SetBody([StdVertexShaderWithTextureForwardString]);

final ShaderObject fragmentShaderFire = ShaderObject("TexturedFragmentForFire")
  ..AddVaryingVars([vTexUV])
  ..AddUniformVars([uTexture])
  ..SetBody([
    """
void main() {
    ${oFragColor}.rgb = texture(${uTexture}, ${vTexUV}).rgb;
}
"""
  ]);

class Demo extends DemoSection {
  final Framebuffer _screen;
  final OrbitCamera _camera;
  late PerspectiveResizeAware perspective;
  final HTML.CanvasElement _canvas;
  final RenderProgram _progCube;
  final RenderProgram _progStars;

  final Material _materialCube;
  final Material _materialStars;
  late HTML.CanvasElement canvas2d;
  late MeshData _cube;
  late MeshData _stars;
  final effects.OldSchool _oldSchoolEffects;

  Demo(cgl, HTML.CanvasElement canvas, HTML.BodyElement body)
      : _canvas = canvas,
        _screen = Framebuffer.Screen(cgl),
        _camera = OrbitCamera(10.0, 10.0, 0.0, canvas),
        _progCube =
            RenderProgram("fireCube", cgl, vertexShader, fragmentShaderFire),
        _progStars = RenderProgram(
            "basic", cgl, pointSpritesVertexShader, pointSpritesFragmentShader),
        _materialCube = Material("cube")
          ..SetUniform(uColor, ColorBlack)
          ..SetUniform(uModelMatrix, VM.Matrix4.identity()),
        _materialStars = Utils.MakeStarMaterial(cgl)
          ..SetUniform(uModelMatrix, VM.Matrix4.identity()),
        _oldSchoolEffects = effects.OldSchool(cgl) {
    perspective = PerspectiveResizeAware(cgl, canvas, _camera, 0.1, 1000.0);
    _stars = Utils.MakeStarMesh(_progStars, 2000, 100.0);
    _cube = ShapeCube(_progCube);

    //

    var modeSelector =
        HTML.document.querySelector('#effect_mode') as HTML.InputElement;
    // _materialFire.ForceUniform(uMode, modeSelector.valueAsNumber!.toDouble());
    modeSelector.onChange.listen((HTML.Event e) {
      var i = e.target as HTML.InputElement;
      _oldSchoolEffects.SwitchMode(i.valueAsNumber!.toDouble());
    });
    modeSelector.dispatchEvent(HTML.Event("change"));
  }

  @override
  String name() {
    return "effects";
  }

  @override
  void Animate(double now, double elapsed, double beat) {
    var texture = _oldSchoolEffects.RenderTexture(now);
    _materialCube.ForceUniform(uTexture, texture);
    _screen.Activate(
        GL_CLEAR_ALL, 0, 0, _canvas.clientWidth, _canvas.clientHeight);

    _camera.azimuth += 0.001;
    _camera.animate(elapsed);
    _progCube.Draw(_cube, [perspective, _materialCube]);

    _progStars.Draw(_stars, [perspective, _materialStars]);
  }

  @override
  double length() {
    // Dummy value, this is not in timeline.
    return 1000;
  }
}
