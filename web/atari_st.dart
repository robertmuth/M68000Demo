import 'dart:html' as HTML;
import 'dart:math' as Math;
import 'dart:typed_data';

import 'demo_section.dart';
import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as VM;
import 'atari_st_font.dart' as FONT;
import 'atari_st_symbols.dart' as SYMBOL_FONT;

import 'demo_font.dart';
import 'mesh.dart';

final ShaderObject instancedVertexShader = ShaderObject("finalV")
  ..AddAttributeVars([aPosition, aNormal, aTexUV])
  ..AddAttributeVars([iaRotation, iaTranslation, iaScale])
  ..AddVaryingVars([vColor, vNormal, vTexUV, vPosition])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix, uTime])
  ..SetBody([
    """

vec3 rotate_vertex_position(vec3 pos, vec4 rot, float t) { 
  
    rot.xyz *= sin(2.5 * rot.w * t) /  length(rot.xyz);
    rot.w = cos(2.5 * rot.w * t);
    return pos + 2.0 * cross(rot.xyz, cross(rot.xyz, pos) + rot.w * pos);
  
  // return pos + 2.0 * cross(rot.xyz, cross(rot.xyz, pos) + rot.w * pos);
}

void main() {
  
  {
    vec3 p = ${aPosition} * ${iaScale};
    p = rotate_vertex_position(p, ${iaRotation}, ${uTime});
    p = p + ${iaTranslation} * smoothstep(0.0, 2.0, ${uTime});
    gl_Position = ${uPerspectiveViewMatrix} * ${uModelMatrix} * vec4(p, 1);
  }
  {
      vec3 n = ${aNormal};
      n = rotate_vertex_position(n, ${iaRotation}, ${uTime});
      ${vNormal} = normalize(n);
  }
  ${vTexUV} = ${aTexUV};
  ${vPosition} = gl_Position.xyz;

  if (${uTime} == -666.0) ${vPosition} = vec3(0);
}
"""
  ]);

final ShaderObject instancedFragmentShader = ShaderObject("finalF")
  ..AddVaryingVars([vColor, vNormal, vTexUV, vPosition])
  ..AddUniformVars(
      [uTexture, uLightDescs, uLightTypes, uShininess, uEyePosition])
  ..SetBody([
    """
void main() {
  ColorComponents acc = CombinedLight(${vPosition},
                                      ${vNormal},
                                      ${uEyePosition},
                                      ${uLightDescs},
                                      ${uLightTypes},
                                      ${uShininess});
                                        
  ${oFragColor}.rgb = texture(${uTexture}, ${vTexUV}).rgb * 0.5 + 
                      acc.diffuse +
                      acc.specular;
}
  """
  ], prolog: [
    StdLibShader
  ]);

final VM.Vector3 dirLight = VM.Vector3(0.0, -50.0, 0.0);

Texture MakeNoiseTesture(ChronosGL cgl, Math.Random rand) {
  HTML.CanvasElement canvas = HTML.CanvasElement();
  canvas.width = 512;
  canvas.height = 512;
  var context = canvas.context2D;
  var image = context.getImageData(0, 0, canvas.width!, canvas.height!);

  for (int i = 0; i < image.data.length; i += 4) {
    int v = 30 + rand.nextInt(225);
    image.data[i + 0] = v;
    image.data[i + 1] = v;
    image.data[i + 2] = v;
    image.data[i + 3] = 255;
  }
  context.putImageData(image, 0, 0);

  return ImageTexture(cgl, "noise", canvas, TexturePropertiesMipmap);
}

final double TEXT_RADIUS = 300;

List<VM.Vector2> MakeScrollerPixels(VM.Vector2 origin, double scale) {
  var font = FONT.font;
  // smoking guy
  List<VM.Vector2> pixels = RenderFontPixelsString(
      'Atari ST * launched 1985 * BTW: "Dave StaUgas loves Bea Hablig"',
      font,
      origin,
      scale);

  // Atari
  origin.x += 100 * 8 * scale;
  pixels.addAll(RenderFontPixelsGlyphs([14, 15], font, origin, scale));
  return pixels;
}

List<VM.Vector2> MakeSmokerPixels(VM.Vector2 origin, double scale) {
  var font = FONT.font;
  // smoking guy
  List<VM.Vector2> pixels =
      RenderFontPixelsGlyphs([28, 29], font, origin, scale);
  origin.y -= 16 * scale;
  pixels.addAll(RenderFontPixelsGlyphs([30, 31], font, origin, scale));
  return pixels;
}

List<VM.Vector2> MakeBeePixels(VM.Vector2 origin, double scale) {
  var font = SYMBOL_FONT.font;
  List<VM.Vector2> pixels = RenderFontPixelsGlyphs([1], font, origin, scale);
  return pixels;
}

List<VM.Vector2> MakeBombPixels(VM.Vector2 origin, double scale) {
  var font = SYMBOL_FONT.font;
  List<VM.Vector2> pixels =
      RenderFontPixelsGlyphs([0, 0, 0], font, origin, scale);
  return pixels;
}

void AddInstanceData(
    MeshData md, Math.Random rand, List<VM.Vector2> pixels, double radius) {
  final Float32List scales = Float32List(pixels.length * 1);
  final Float32List translations = Float32List(pixels.length * 3);
  final Float32List rotations = Float32List(pixels.length * 4);

  int n = 0;
  for (final VM.Vector2 p in pixels) {
    double angle = p.x / radius * Math.pi * 2.0 / 8;
    translations[n * 3 + 0] = Math.sin(angle) * radius;
    translations[n * 3 + 1] = p.y * 1.2;
    translations[n * 3 + 2] = Math.cos(angle) * radius;
    //
    // var u = VM.Vector3.random(rand);
    // var q = VM.Quaternion.axisAngle(u, 2.0 * rand.nextDouble() * Math.pi);
    var q = VM.Quaternion.euler(0.0, angle, 0.0);
    rotations.setAll(n * 4, q.storage);
    //
    scales.setAll(n, [1.0]);
    ++n;
  }

  md.AddAttribute(iaRotation, rotations, 4);
  md.AddAttribute(iaTranslation, translations, 3);
  md.AddAttribute(iaScale, scales, 1);
}

final ShaderObject vertexShader = ShaderObject("normalVertexColorV")
  ..AddAttributeVars([aPosition, aNormal])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..AddVaryingVars([vColor])
  ..SetBodyWithMain([
    StdVertexBody,
    "${vColor} = abs(${aNormal});",
  ], prolog: [
    StdLibShader
  ]);

final ShaderObject fragmentShader = ShaderObject("normalVertexColorF")
  ..AddVaryingVars([vColor])
  ..SetBodyWithMain(["${oFragColor} = vec4( ${vColor}, 1.0 );"]);

class Demo extends DemoSection {
  OrbitCamera camera;
  late PerspectiveResizeAware perspective;
  late Illumination illumination;
  //
  RenderProgram progAtari;
  RenderProgram progStars;
  RenderProgram progScroller;

  Material materialAtari;
  Material materialStars;
  Material materialScroller;

  late MeshData atari;
  late MeshData stars;
  late MeshData scroller;
  late MeshData bee;
  late MeshData bombs;
  late MeshData smoker;

  static const String model = "Assets/AtariST/AtariST.glb";

  Demo(cgl, HTML.CanvasElement canvas, HTML.BodyElement body)
      : camera = OrbitCamera(500.0, 0.0, 0.0, canvas),
        illumination = Illumination()
          ..AddLight(DirectionalLight(
              "dir", dirLight, ColorWhite * 0.5, ColorBlack, 100.0)),
        progAtari = RenderProgram("demo", cgl, vertexShader, fragmentShader),
        progStars = RenderProgram(
            "basic", cgl, pointSpritesVertexShader, pointSpritesFragmentShader),
        progScroller = RenderProgram(
            "instanced", cgl, instancedVertexShader, instancedFragmentShader),
        materialAtari = Material("matAtari")
          ..SetUniform(
              uModelMatrix,
              VM.Matrix4.identity()
                ..scale(350)
                ..rotateX(0.5 * Math.pi)),
        materialScroller = Material("matScroller")
          ..SetUniform(uModelMatrix, VM.Matrix4.identity())
          ..SetUniform(uShininess, 10.0),
        materialStars = Utils.MakeStarMaterial(cgl, 4000)
          ..SetUniform(uModelMatrix, VM.Matrix4.identity()) {
    perspective = PerspectiveResizeAware(cgl, canvas, camera, 0.1, 2000.0);
    stars = Utils.MakeStarMesh(progStars, 2000, 1000.0);
    final Math.Random rand = Math.Random(1);

    var noiseTexture = MakeNoiseTesture(cgl, rand);
    //
    {
      materialScroller.SetUniform(uTexture, noiseTexture);
      scroller = ShapeCube(progScroller, computeNormals: true);
      var pixels = MakeScrollerPixels(VM.Vector2(-400.0, 50.0), 2.0);
      AddInstanceData(scroller, rand, pixels, TEXT_RADIUS);
      print("instances: ${scroller.GetNumInstances()}");
    }
    //
    {
      double scale = 1.0;
      bee = ShapeCube(progScroller,
          x: scale, y: scale, z: scale, computeNormals: true);
      var pixels = MakeBeePixels(VM.Vector2(470.0, 30.0), 2.0 * scale);
      AddInstanceData(bee, rand, pixels, TEXT_RADIUS * 0.4);
    }
    //
    {
      double scale = 1.0;
      bombs = ShapeCube(progScroller,
          x: scale, y: scale, z: scale, computeNormals: true);
      var pixels = MakeBombPixels(VM.Vector2(800.0, 40.0), 1.5 * scale);
      AddInstanceData(bombs, rand, pixels, TEXT_RADIUS);
    }
    //
    {
      double scale = 1.0;
      smoker = ShapeCube(progScroller,
          x: scale, y: scale, z: scale, computeNormals: true);
      var pixels = MakeSmokerPixels(VM.Vector2(-20.0, 60.0), 2.0 * scale);
      AddInstanceData(smoker, rand, pixels, TEXT_RADIUS * 0.4);
    }
    //
    camera.azimuth = -0.5 * Math.pi;
  }

  @override
  String name() {
    return "atari_st";
  }

  @override
  void Animate(double now, double elapsed, double beat) {
    camera.azimuth -= 0.004;
    camera.animate(elapsed);
    progAtari.Draw(atari, [perspective, materialAtari]);

    progStars.Draw(stars, [perspective, materialStars]);

    materialScroller.ForceUniform(uTime, now / 2000.0);
    progScroller.Draw(scroller, [materialScroller, perspective, illumination]);
    progScroller.Draw(bee, [materialScroller, perspective, illumination]);
    progScroller.Draw(bombs, [materialScroller, perspective, illumination]);
    progScroller.Draw(smoker, [materialScroller, perspective, illumination]);
  }

  @override
  void Init(List<Future<Object>> loadables) {
    loadables.add(Mesh.load(model)
      ..then((List<Mesh> meshes) {
        print("Atari Future completed");
        atari = meshes[0].parts[0].build('Atari', progAtari);
      }));
  }

  @override
  double length() {
    return 24000;
  }
}
