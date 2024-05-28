import 'dart:html' as HTML;
import 'dart:math' as Math;

import 'assets.dart' as assets;
import 'demo_section.dart';
import 'mesh.dart';
import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as VM;

const int kStrips = 4;
int kHeight = 256;
int kWidth = 8192;

const String FONT = "150px monospace";

// We need to break this up because Firefox has bug
// preventing it from rendering long strings.
const List<String> TEXT = [
  "Motorola 68000 ",
  "  ●  launched 1979",
  "  ●  32 bit CPU",
  "  ●  16 bit bus",
  "  ●  16 registers (8 data + 8 address)",
  "  ●  linear address space (no segments)",
  "  ●  1.4 MIPS at 8 Mhz",
  "  ●  64 pin package (aka the Texas Cockroach)       ",
  "It was a joy to program.      ",
  "This is an homage to the awesome home computers ",
  "it made possible ..."
];

HTML.CanvasElement MakeCanvasForTexture(HTML.ImageElement? img) {
  // the " -1 " is necessary for firefox to stay at or below the max canvas
  // width of 32,767 pixels
  final canvas2 =
      HTML.CanvasElement(width: kStrips * kWidth - 1, height: kHeight);
  HTML.CanvasRenderingContext2D ctx2 =
      canvas2.getContext('2d') as HTML.CanvasRenderingContext2D;
  if (img != null) ctx2.drawImage(img, 400, 10);
  ctx2.fillStyle = "white";
  ctx2.font = FONT;
  print(HTML.window.navigator.userAgent);
  int offset = 2200;
  for (String txt in TEXT) {
    ctx2.fillText(txt, offset, 175);
    offset += ctx2.measureText(txt).width!.toInt();
  }

  //ctx.fillRect(77, 77, 100, 100);

  final canvas = HTML.CanvasElement(width: kWidth, height: kStrips * kHeight);
  HTML.CanvasRenderingContext2D ctx =
      canvas.getContext('2d') as HTML.CanvasRenderingContext2D;

  for (int i = 0; i < 4; ++i) {
    var src = HTML.Rectangle<int>(i * kWidth, 0, kWidth, kHeight);
    var dst = HTML.Rectangle<int>(0, i * kHeight, kWidth, kHeight);

    ctx.drawImageToRect(canvas2, dst, sourceRect: src);
  }
  return canvas;
}

final ShaderObject vertexShaderHousing = ShaderObject("normalVertexColorV")
  ..AddAttributeVars([aPosition, aTexUV, aNormal])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..AddVaryingVars([vColor, vTexUV])
  ..SetBodyWithMain([
    StdVertexBody,
    """
    ${vTexUV} = vec2(${aTexUV}.x, 1.0 - ${aTexUV}.y);
    ${vColor} = abs(${aNormal}) * 10.0;
    """
  ], prolog: [
    StdLibShader
  ]);

final ShaderObject fragmentShaderHousing = ShaderObject("normalVertexColorF")
  ..AddVaryingVars([vColor, vTexUV])
  ..AddUniformVars([uTexture, uTime])
  ..SetBodyWithMain([
    """
  float x_tex_fraction = 8.0;
  float x_tex_offset = 0.5;
  float speed = 0.0011;

  if (-1.7 <= ${vTexUV}.x && ${vTexUV}.x <=  2.7 && 
      -0.1 <= ${vTexUV}.y && ${vTexUV}.y <=  1.2) {
       // normalize it to (0,0) -> (1,1)
       vec2 norm_uv = (${vTexUV} - vec2(-1.7,-0.1)) / vec2(4.4, 1.3);
       norm_uv.x = norm_uv.x += speed * ${uTime};
       norm_uv.x = norm_uv.x / x_tex_fraction;

      norm_uv.y = norm_uv.y * 0.25;
      norm_uv.y = norm_uv.y + 0.75;
      while(norm_uv.x > 1.0) {
        norm_uv.y = norm_uv.y - 0.25;
        norm_uv.x = norm_uv.x - 1.0;
      }
      vec4 partCode = texture(${uTexture}, norm_uv);
      ${oFragColor}.rgb = partCode.rgb;
      ${oFragColor}.r = 0.5;
  } else {
    ${oFragColor}.rgb = ${vColor};
  }
"""
  ]);

final ShaderObject vertexShaderPins = ShaderObject("normalVertexColorV")
  ..AddAttributeVars([aPosition, aNormal])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..AddVaryingVars([vColor])
  ..SetBodyWithMain([
    StdVertexBody,
    "${vColor} = abs(${aNormal}) * 5.0;",
  ], prolog: [
    StdLibShader
  ]);

final ShaderObject fragmentShaderPins = ShaderObject("normalVertexColorF")
  ..AddVaryingVars([vColor])
  ..SetBodyWithMain(["${oFragColor} = vec4( ${vColor}, 1.0 );"]);

final VM.Matrix4 modelMatrix = VM.Matrix4.identity()..rotateX(0.25 * Math.pi);

class Demo extends DemoSection {
  OrbitCamera camera;
  late PerspectiveResizeAware perspective;
  RenderProgram progHousing;
  RenderProgram progPins;
  RenderProgram progStars;
  Material materialHousing;
  Material materialPins;
  Material materialStars;

  late MeshData housing;
  late MeshData pins;
  late MeshData stars;
  late ImageTexture scrollTexture;

  static const String model = "Assets/M68000/M68000.glb";
  static const partCodeURL = 'Assets/M68000/PartCode.png';

  Demo(cgl, HTML.CanvasElement canvas, HTML.BodyElement body)
      : camera = OrbitCamera(1.0, 0.0, 0.0, canvas),
        progHousing = RenderProgram(
            "demo", cgl, vertexShaderHousing, fragmentShaderHousing),
        progPins =
            RenderProgram("demo", cgl, vertexShaderPins, fragmentShaderPins),
        progStars = RenderProgram(
            "basic", cgl, pointSpritesVertexShader, pointSpritesFragmentShader),
        materialHousing = Material("mat")
          ..SetUniform(uModelMatrix, modelMatrix),
        materialPins = Material("mat")..SetUniform(uModelMatrix, modelMatrix),
        materialStars = Utils.MakeStarMaterial(cgl)
          ..SetUniform(uModelMatrix, VM.Matrix4.identity()) {
    perspective = PerspectiveResizeAware(cgl, canvas, camera, 0.001, 1000.0);
    stars = Utils.MakeStarMesh(progStars, 2000, 100.0);
    camera.azimuth = 0.5 * Math.pi;
  }

  @override
  String name() {
    return "m68000";
  }

  double INITIAL_WAIT = 2500;

  @override
  void Animate(double now, double elapsed, double beat) {
    camera.azimuth += 0.0005;
    camera.animate(elapsed);
    // Wait before scrolling
    materialHousing.ForceUniform(
        uTime, now < INITIAL_WAIT ? 0 : now - INITIAL_WAIT);

    progHousing.Draw(housing, [perspective, materialHousing]);
    progPins.Draw(pins, [perspective, materialPins]);

    progStars.Draw(stars, [perspective, materialStars]);
  }

  @override
  void Init(List<Future<Object>> loadables) {
    loadables.add(Mesh.load(model)
      ..then((List<Mesh> meshes) {
        print("M68000 Future copmpleted");
        for (var mesh in meshes) {
          for (var part in mesh.parts) {
            switch (part.material) {
              case 'Housing':
                housing = part.build('M68000/Housing', progHousing);
                break;
              case 'Pin':
                pins = part.build('M68000/Pins', progPins);
                break;
              default:
                HTML.window.console.warn("Unknown material: ${part.material}");
                break;
            }
          }
        }
      }));
    loadables.add(assets.loadImage(partCodeURL)
      ..then((HTML.ImageElement img) {
        scrollTexture = ImageTexture(
            progPins.getContext(), partCodeURL, MakeCanvasForTexture(img));
        materialHousing.SetUniform(uTexture, scrollTexture);
      }));
  }

  @override
  double length() {
    return 30000;
  }
}
