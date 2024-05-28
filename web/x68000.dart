import 'dart:html' as HTML;
import 'dart:math' as Math;

import 'demo_section.dart';
import 'mesh.dart';
import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as VM;

import 'effects.dart' as effects;
import 'animations.dart' as anim;

String INTRO = """Sharp X68000  
Launched 1987. 
Sold only in Japan.
We don't know much about it.

So how about ...          
... some oldskool effects?
""";

String PLASMA = """

   Give it up for Plasma!  """;

String TUNNEL = """


   Yeah Tunnel Effect!
   Are you gettig dizzy?  """;

String RASTER_BARS = """

    Raster Bars! 
       Hooray!  """;

String FIRE = """


     Fire - so hot!  """;

String THE_END = """
        
          Fin  """;

String CREDIT = """
        Created By 
Dietrich Epp & Robert Muth
 
           for

      @party 2023   """;

final String uScreenCoordinates = 'uScreenCoordinates';
final String uScreenAspect = 'uScreenAspect';

final screenCenter = VM.Vector3(-0.132848, 0.043314, 0.025847);
final screenScale = 8.0;

final modelMatrix = VM.Matrix4.identity()..rotateX(Math.pi * 0.5);

final ShaderObject vertexShader = ShaderObject("normalVertexColorV")
  ..AddAttributeVars([aPosition, aNormal])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..AddVaryingVars([vColor])
  ..SetBodyWithMain([
    StdVertexBody,
    "${vColor} = abs(${aNormal}) * 10.0;",
  ], prolog: [
    StdLibShader
  ]);

final ShaderObject fragmentShader = ShaderObject("normalVertexColorFScreen")
  ..AddVaryingVars([vColor])
  ..SetBodyWithMain(["${oFragColor} = vec4( ${vColor}, 1.0 );"]);

final ShaderObject screenVertexShader = ShaderObject("normalVertexColorVScreen")
  ..AddAttributeVars([aPosition, aNormal])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix, uScreenCoordinates])
  ..AddVaryingVars([vTexUV])
  ..SetBodyWithMain([
    """
    vec4 pos = ${uModelMatrix} * vec4(${aPosition}, 1.0);
    ${vTexUV} = (${uScreenCoordinates} * pos).xy;
    gl_Position = ${uPerspectiveViewMatrix} * pos;
    """,
  ], prolog: [
    StdLibShader
  ]);

final ShaderObject screenFragmentShader = ShaderObject("normalVertexColorF")
  ..AddUniformVars([uScreenAspect, uTexture])
  ..AddVaryingVars([vTexUV])
  ..SetBody([
    """

vec3 ScanLine() {
  vec2 uv = gl_FragCoord.xy / float(1024);
  float count = float(2500);
  vec2 sl = vec2(sin(uv.y * count), cos(uv.y * count));
	vec3 scanlines = vec3(sl.x, sl.y, sl.x);

  return scanlines * 1.2;
}

void main() {
    vec2 screenuv = 0.5 * (${vTexUV} + ${uScreenAspect});
    vec2 inscreen2 = step(abs(${vTexUV}), ${uScreenAspect});
    float inscreen = inscreen2.x * inscreen2.y;
    ${oFragColor}.rgb =  texture(${uTexture}, screenuv).rgb * inscreen 
        /* * ScanLine() */;
}
    """
  ]);

final HTML.Element azimuth =
    HTML.document.querySelector('#azimuth') as HTML.Element;

class Demo extends DemoSection {
  final HTML.CanvasElement _canvas;
  final Framebuffer _screen;
  OrbitCamera camera;
  late PerspectiveResizeAware perspective;
  RenderProgram prog;
  RenderProgram progScreen;
  RenderProgram progStars;
  Material material;
  Material materialScreen;
  Material materialStars;

  late MeshData logo;
  late MeshData screen;
  late MeshData stars;

  late ImageTexture screenTexture;
  final effects.OldSchool _oldSchoolEffects;

  static const String model = "Assets/X68000/X68000.glb";
  late anim.AnimationSequence _sequence_rotation;
  late anim.AnimationSequence _sequence;

  Demo(cgl, HTML.CanvasElement canvas, HTML.BodyElement body)
      : _canvas = canvas,
        _screen = Framebuffer.Screen(cgl),
        camera = OrbitCamera(0.8, 0.0, 0.0, canvas),
        prog = RenderProgram("demo", cgl, vertexShader, fragmentShader),
        progScreen = RenderProgram(
            "demo.screen", cgl, screenVertexShader, screenFragmentShader),
        progStars = RenderProgram(
            "basic", cgl, pointSpritesVertexShader, pointSpritesFragmentShader),
        material = Material("mat")..SetUniform(uModelMatrix, modelMatrix),
        materialScreen = Material("mat")
          ..SetUniform(uModelMatrix, modelMatrix)
          ..SetUniform(
              uScreenCoordinates,
              VM.Matrix4.identity()
                ..scale(screenScale)
                ..translate(-screenCenter))
          ..SetUniform(uScreenAspect, VM.Vector2(1.0, 0.75)),
        materialStars = Utils.MakeStarMaterial(cgl)
          ..SetUniform(uModelMatrix, modelMatrix),
        _oldSchoolEffects = effects.OldSchool(cgl) {
    perspective = PerspectiveResizeAware(cgl, canvas, camera, 0.001, 100.0);
    stars = Utils.MakeStarMesh(progStars, 2000, 100.0);
    var dummy_canvas = HTML.CanvasElement(width: 128, height: 128);
    var blackTexture = ImageTexture(cgl, "gen", dummy_canvas);
    screenTexture = ImageTexture(cgl, "gen", dummy_canvas);
    materialScreen.ForceUniform(uTexture, screenTexture);

    camera.azimuth = 0.0;
    _sequence_rotation = anim.AnimationSequence([
      // intro
      anim.RotateAnimation(1000, 0.5 * Math.pi, camera, force_start: 0.0),
      anim.NullAnimation(4500),
      // plasma
      anim.RotateAnimation(2000, 2.5 * Math.pi, camera),
      anim.NullAnimation(5000),
      anim.NullAnimation(3000),
      // tunnel
      anim.RotateAnimation(2000, 4.5 * Math.pi, camera),
      anim.NullAnimation(6000),
      // raster bars
      anim.RotateAnimation(2000, 6.5 * Math.pi, camera),
      anim.NullAnimation(6500),
      // fire
      anim.RotateAnimation(2000, 8.5 * Math.pi, camera),
      anim.NullAnimation(6500),
      // end
      anim.RotateAnimation(2000, 10.5 * Math.pi, camera),
      anim.NullAnimation(2000),
      // creadit
      anim.RotateAnimation(2000, 12.5 * Math.pi, camera),
      anim.NullAnimation(3500),
    ]);

    // not we switch halfway through the rotation
    _sequence = anim.AnimationSequence([
      anim.FixedAnimation(1000, blackTexture),
      anim.TextAnimation(5500, INTRO, screenTexture),
      //
      anim.OldSkoolAnimation(6000, 4.0, _oldSchoolEffects),
      anim.TextAnimation(4000, PLASMA, screenTexture),
      //
      anim.OldSkoolAnimation(6000, 3.0, _oldSchoolEffects),
      anim.TextAnimation(2500, TUNNEL, screenTexture),
      //
      anim.OldSkoolAnimation(6000, 2.0, _oldSchoolEffects),
      anim.TextAnimation(2500, RASTER_BARS, screenTexture),
      //
      anim.OldSkoolAnimation(6000, 1.0, _oldSchoolEffects),
      anim.TextAnimation(2500, FIRE, screenTexture),
      //
      anim.FixedAnimation(1000, blackTexture),
      anim.TextAnimation(3000, THE_END, screenTexture),
      //
      anim.FixedAnimation(1000, blackTexture),
      anim.TextAnimation(3000, CREDIT, screenTexture),
    ]);
    print(_sequence_rotation.Duration());
    print(_sequence.Duration());
    assert(_sequence_rotation.Duration() == _sequence.Duration());
  }

  @override
  String name() {
    return "x68000";
  }

  @override
  void Animate(double now, double elapsed, double beat) {
    _sequence_rotation.Run(now, elapsed);
    var texture = _sequence.Run(now, elapsed);
    if (texture != null) {
      materialScreen.ForceUniform(uTexture, texture);
    }
    _screen.Activate(
        GL_CLEAR_ALL, 0, 0, _canvas.clientWidth, _canvas.clientHeight);
    camera.animate(elapsed);
    prog.Draw(logo, [perspective, material]);
    progScreen.Draw(screen, [perspective, materialScreen]);

    progStars.Draw(stars, [perspective, materialStars]);
  }

  @override
  void Init(List<Future<Object>> loadables) {
    var future = Mesh.load(model)
      ..then((List<Mesh> meshes) {
        print("X68000 Future completed");
        for (Mesh mesh in meshes) {
          for (MeshPart part in mesh.parts) {
            switch (part.material) {
              case 'Case':
                logo = part.build("X68000/Case", prog);
                break;
              case 'Screen':
                screen = part.build("X68000/Screen", progScreen);
                break;
              default:
                HTML.window.console.warn("Unknown material: ${part.material}");
                break;
            }
          }
        }
      });
    loadables.add(future);
  }

  @override
  double length() {
    return _sequence.Duration();
  }
}
