import 'dart:html' as HTML;
import 'dart:math' as Math;

import 'demo_section.dart';
import 'mesh.dart';
import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as VM;

import 'effects.dart' as effects;
import 'animations.dart' as anim;

const int macCount = 11;

String MAC_INTRO = """Apple Macintosh
Launched in 1984.

Never had much traction 
in the Demoscene.

Lets see what we've got ...  """;

String NO_WAY = """Come on!
There is no way fractal
zooming worked on a Mac.

Give us something machine 
appropriate.  """;

String SACKED = """We apologise for the 
machine inappropriate effect.  
Those responsible have been 
sacked.  """;

String SACKED2 = """We apologise again for the 
inappropriate effects.  
Those responsible for sacking 
the people who have just been 
sacked have been sacked.  """;

final String uScreenCoordinates = 'uScreenCoordinates';
final String uScreenAspect = 'uScreenAspect';
final String vTexUV2 = 'vTexUV2';

// Screen mesh:
//   dimensions: 19cm x 15cm
//   center: (0.000000,0.061520,0.112698)
// At 72 ppi, 512px, scale is: 1/(0.0254 in/m) (72 ppi) 1/(512 px)
// Then scale by 0.5 so coordinates go from -1 to +1 across screen.
final screenCenter = VM.Vector3(0.000000, 0.061520, 0.112698);
const screenScale = (72.0) / (512 * 0.0254 * 0.5);

final modelMatrix = VM.Matrix4.identity();

final ShaderObject computerVertexShader = ShaderObject("computerVertexShader")
  ..AddAttributeVars([aPosition, aNormal, aTexUV])
  ..AddVaryingVars([vColor])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..SetBody([
    """
void main() {
    gl_Position = ${uPerspectiveViewMatrix} *
                  ${uModelMatrix} *
                  vec4(${aPosition}, 1.0);
    ${vColor} = abs(${aNormal}) * 5.0;
}
"""
  ]);

final ShaderObject computerFragmentShader =
    ShaderObject("computerFragmentShader")
      ..AddVaryingVars([vColor])
      ..SetBody([
        """
void main() {
    ${oFragColor}.brg = ${vColor}.rgb;
}
    """
      ]);

final ShaderObject screenVertexShader = ShaderObject("screenVertexShader")
  ..AddAttributeVars([aPosition, aNormal, aTexUV])
  ..AddVaryingVars([vNormal, vTexUV, vTexUV2])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix, uScreenCoordinates])
  ..SetBody([
    """
void main() {
    vec4 pos = ${uModelMatrix} * vec4(${aPosition}, 1.0);
    gl_Position = ${uPerspectiveViewMatrix} * pos;
    ${vNormal} = ${aNormal};
    ${vTexUV} = ${aTexUV};
    ${vTexUV2} = (${uScreenCoordinates} * vec4(${aPosition}, 1.0)).xy;
}
"""
  ]);

final ShaderObject screenFragmentShader = ShaderObject("screenFragmentShader")
  ..AddVaryingVars([vNormal, vTexUV, vTexUV2])
  ..AddUniformVars([uTexture, uScreenAspect])
  ..SetBody([
    """
void main() {
    float ao = texture(${uTexture}, ${vTexUV}).r;
    vec2 screenuv = 0.5 * (${vTexUV2} + ${uScreenAspect});
    vec3 screencolor = texture(${uTexture}, screenuv).rgb;
    vec2 inscreen2 = step(abs(vTexUV2), uScreenAspect);
    float inscreen = inscreen2.x * inscreen2.y;
    screencolor *= inscreen;
    ${oFragColor} = vec4(screencolor, 1.0);
}
    """
  ]);

double triangle(double x) {
  return 0.5 - 2 * (0.5 - x + x.floor()).abs();
}

final HTML.Element azimuth =
    HTML.document.querySelector('#azimuth') as HTML.Element;

class Demo extends DemoSection {
  final HTML.CanvasElement _canvas;
  final Framebuffer _screen;
  double time = 0.0;
  OrbitCamera camera;
  late PerspectiveResizeAware perspective;
  RenderProgram caseProg;
  RenderProgram screenProg;
  RenderProgram progStars;

  Material caseMaterial;
  late ImageTexture screenTexture;
  Material screenMaterial;
  Material materialStars;

  late MeshData? caseMesh;
  late MeshData? screenMesh;
  late MeshData stars;

  final effects.OldSchool _oldSchoolEffects;
  late anim.AnimationSequence _sequence;

  double camera_delta = 0.002;

  Demo(ChronosGL cgl, HTML.CanvasElement canvas, HTML.BodyElement body)
      : _canvas = canvas,
        _screen = Framebuffer.Screen(cgl),
        camera = OrbitCamera(0.7, 0.0, 0.0, canvas),
        caseProg = RenderProgram(
            "computer", cgl, computerVertexShader, computerFragmentShader),
        screenProg = RenderProgram(
            "screen", cgl, screenVertexShader, screenFragmentShader),
        progStars = RenderProgram(
            "basic", cgl, pointSpritesVertexShader, pointSpritesFragmentShader),
        caseMaterial = Material("mat")..SetUniform(uModelMatrix, modelMatrix),
        materialStars = Utils.MakeStarMaterial(cgl)
          ..SetUniform(uModelMatrix, modelMatrix),
        screenMaterial = Material("screen_mat")
          ..SetUniform(uModelMatrix, modelMatrix)
          ..SetUniform(
              uScreenCoordinates,
              VM.Matrix4.identity()
                ..scale(screenScale)
                ..translate(-screenCenter))
          ..SetUniform(uScreenAspect, VM.Vector2(1.0, 0.75)),
        _oldSchoolEffects = effects.OldSchool(cgl) {
    perspective = PerspectiveResizeAware(cgl, canvas, camera, 0.1, 100.0);

    screenTexture =
        ImageTexture(cgl, "gen", HTML.CanvasElement(width: 16, height: 16));
    screenMaterial.SetUniform(uTexture, screenTexture);
    stars = Utils.MakeStarMesh(progStars, 2000, 50.0);
    camera.azimuth = 0.5 * Math.pi;
    _sequence = anim.AnimationSequence([
      anim.MacTextAnimation(4000, MAC_INTRO, screenTexture),
      // fractal
      anim.OldSkoolAnimation(2500, 13.0, _oldSchoolEffects),
      anim.MacTextAnimation(4000, NO_WAY, screenTexture),
      // amiga
      anim.OldSkoolAnimation(2500, 12.0, _oldSchoolEffects),
      anim.MacTextAnimation(4000, SACKED, screenTexture),
      //
      anim.OldSkoolAnimation(2500, 14.0, _oldSchoolEffects),
      anim.MacTextAnimation(4500, SACKED2, screenTexture),
    ]);
  }

  @override
  String name() {
    return "macintosh";
  }

  @override
  void Animate(double now, double elapsed, double beat) {
    var texture = _sequence.Run(now, elapsed);
    if (texture != null) {
      screenMaterial.ForceUniform(uTexture, texture);
    }

    _screen.Activate(
        GL_CLEAR_ALL, 0, 0, _canvas.clientWidth, _canvas.clientHeight);
    if (camera.azimuth > 0.6 * Math.pi) {
      camera_delta = -camera_delta.abs();
    } else if (camera.azimuth < 0.4 * Math.pi) {
      camera_delta = camera_delta.abs();
    }
    camera.azimuth += camera_delta;
    azimuth.setInnerHtml("azi: ${camera.azimuth}");
    camera.animate(elapsed);
    final middle = macCount ~/ 2;
    double basey = (beat / (8 * 4) - 1) * 1.5 - 0.5;
    double dy = triangle(beat / 8);
    for (int i = 0; i < macCount; i++) {
      modelMatrix.setIdentity();
      if (i != middle) {
        double y = (i & 1) == 0 ? basey + dy : basey - dy;
        modelMatrix.translate(0.2 * (i - middle), y + Math.cos(i * 5),
            -1 + 0.5 * Math.sin(i * 7));
      }
      caseProg.Draw(caseMesh!, [perspective, caseMaterial]);
      screenProg.Draw(screenMesh!, [perspective, screenMaterial]);
    }
    progStars.Draw(stars, [perspective, materialStars]);
  }

  @override
  void Init(List<Future<Object>> loadables) {
    loadables.add(Mesh.load('Assets/Mac/Mac.glb')
      ..then((List<Mesh> meshes) {
        print("Mac Future completed");
        for (var mesh in meshes) {
          for (var part in mesh.parts) {
            switch (part.material) {
              case 'Case':
                caseMesh = part.build('Mac/Case', caseProg);
                break;
              case 'Screen':
                screenMesh = part.build('Mac/Screen', screenProg);
                break;
              default:
                HTML.window.console.warn("Unknown material: part.material");
                break;
            }
          }
        }
      }));
  }

  @override
  double length() {
    return _sequence.Duration();
  }
}
