import 'dart:math' as Math;
import 'dart:html' as HTML;
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as VM;

import 'assets.dart' as assets;
import 'demo_font.dart';
import 'demo_section.dart';
import 'atari_st_font.dart' as FONT;

const String aCurrentPosition = "aCurrentPosition";
const String aNoise = "aNoise";

const int DEFLATE_START = 1;
const int DEFLATE_END = 2;
const int INFLATE_START = 3;
const int INFLATE_END = 4;
const int PERIOD = INFLATE_END;

const int NUM_POINTS = 8 * 1000 * 1000;
const LETTER_SCALE = 4.0;

final ShaderObject dustVertexShader = ShaderObject("dustV")
  ..AddAttributeVars([aPosition, aCurrentPosition, aNoise, aNormal])
  ..AddVaryingVars([vColor])
  ..AddTransformVars([tPosition])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix, uTime, uPointSize])
  ..SetBody([
    """

const float bottom = -150.0;
const vec3 gray = vec3(0.5);
const vec3 SPREAD_VOL = vec3(500.0, 2.0, 100.0);

float ip(float start, float end, float x) {
  //return smoothstep(start, end, x);
  
  if (x <= start) return 0.0;
  if (x >= end) return 1.0;
  return (x - start) / (end - start);
}

// deterministic rng: result is between vec3(-.5) and vec3(.5)
vec3 GetNoise(float seed) {
  return vec3(fract(${aNoise} * seed), 
              fract(${aNoise} * seed * 100.0), 
              fract(${aNoise} * seed * 10000.0)) - vec3(0.5);
}
vec3 GetVertexNoise(vec3 noise, float x) {
  return vec3(2.0 + 500.0 * x, 5.0 + 500.0 * x , 10.0 + 500.0 * x) * noise;
}
void main() {
  
    vec3 curr_pos = ${aCurrentPosition};
    
    vec3 orig_pos = ${aPosition};
    vec3 orig_col = abs(${aNormal}.xyz);
  
   vec3 noise = GetNoise(1.1);

    vec3 color_noise =  0.4 * noise ;
    float time_noise =  0.3 * length(noise);
    // time_noise = 0.0;
    float t = mod(${uTime} - time_noise, float(${PERIOD}));

    vec3 new_pos;
    vec3 new_col;     

    if (t <= float(${DEFLATE_START})) { 
      new_pos = orig_pos;
      new_col = orig_col;
    } else if (t < float(${DEFLATE_END})) { 
      float x =  ip(float(${DEFLATE_START}), float(${DEFLATE_END}), t);
      new_pos = mix(orig_pos, 
                    vec3(curr_pos.x, bottom, curr_pos.z) + GetVertexNoise(noise, 1.0 - x), x);
      new_col = mix(orig_col, gray + color_noise, x);


    } else if (t < float(${INFLATE_START})) { 
       new_pos = curr_pos;
       new_col = gray + color_noise;
    } else { 
      float x =  ip(float(${INFLATE_START}), float(${INFLATE_END}), t);
      new_pos =  mix(vec3(curr_pos.x, bottom, curr_pos.z) + GetVertexNoise(noise, x),
                     orig_pos, x);
      new_col = mix(gray + color_noise, orig_col, x);
    } 

/*
    float t = mod(${uTime}, float(${PERIOD}));

    vec3 noise0 = GetNoise(1.1);

    // https://en.wikipedia.org/wiki/Box%E2%80%93Muller_transform

    vec3 noise1 = GetNoise(2.2);
    vec3 noise2 = GetNoise(3.3);
    vec3 noise3 = GetNoise(4.4);

    vec3 noiseT = GetNoise(t);

    vec3 color_noise =  0.4 * noise0;
    float time_noise =  0.3 * length(noise0);



    vec3 pile_col = gray + color_noise;
    vec3 pile_pos = SPREAD_VOL * (noise0 + noise1 + noise2 + noise3);
    pile_pos.y = abs(pile_pos.y) + bottom;

    vec3 new_pos;
    vec3 new_col;     

    if (t <= float(${DEFLATE_START})) { 
      new_pos = orig_pos;
      new_col = orig_col;
    } else if (t < float(${DEFLATE_END})) { 
      float x =  ip(float(${DEFLATE_START}), float(${DEFLATE_END}), t);
      //vec3 noisy_pile_pos =  pile_pos + noiseT * SPREAD_VOL * 0.1 * (1.0 - x);
      vec3 noisy_pile_pos =  pile_pos;

      new_pos = mix(curr_pos, noisy_pile_pos, x);
      new_col = mix(orig_col, pile_col, x);
    } else if (t < float(${INFLATE_START})) { 
       new_pos = curr_pos;
       new_col = pile_col;
    } else { 
      float x =  ip(float(${INFLATE_START}), float(${INFLATE_END}), t);
      new_pos =  mix(curr_pos + noiseT * SPREAD_VOL * 0.1, orig_pos, x);
      new_col = mix(pile_col, orig_col, x);
    } 
*/
  
    // will become aCurrentPosition int the next run
    ${tPosition} = new_pos;
    ${vColor}.rgb  = new_col;
    gl_Position = ${uPerspectiveViewMatrix} * ${uModelMatrix} * vec4(new_pos, 1.0);
    gl_PointSize = ${uPointSize} / gl_Position.z;
}
"""
  ]);

final ShaderObject dustFragmentShader = ShaderObject("dustF")
  ..AddVaryingVars([vColor])
  ..SetBody([
    """
void main() {  
    ${oFragColor}.rgb = ${vColor};
}
    """
  ]);

MeshData MakePointCloudForText(String text, var font, RenderProgram prog,
    VM.Vector2 origin, double scale) {
  var o = origin.clone();
  // TODO: explain math
  o.x -= text.length * scale * 4;
  List<VM.Vector2> pixels = RenderFontPixelsString(text, font, o, scale);
  GeometryBuilder gb = MakeMeshForPixels(pixels, scale * 0.7);
  MeshData triangles = GeometryBuilderToMeshData("", prog, gb);
  MeshData points = ExtractPointCloud(prog, triangles, NUM_POINTS);
  print("done with text: ${text}");
  return points;
}

MeshData MakePointCloudForWaveFront(String content, RenderProgram prog) {
  GeometryBuilder gb = ImportGeometryFromWavefront(content);
  for (int i = 0; i < gb.vertices.length; ++i) {
    var v = gb.vertices[i].clone();
    v.scale(3.0);

    gb.vertices[i] = v;
  }
  MeshData logo = GeometryBuilderToMeshData("", prog, gb);
  return ExtractPointCloud(prog, logo, NUM_POINTS);
}

Future<MeshData> MakePointCloudForWaveFrontURL(
    String url, RenderProgram prog) async {
  String content = await assets.getText(url);
  // Error handling in ChronosGL needs to be improved.
  if (content.length < 100) {
    HTML.window.alert("load failed for ${url}");
  }

  return MakePointCloudForWaveFront(content, prog);
}

class Demo extends DemoSection {
  ChronosGL cgl;
  OrbitCamera camera;
  late PerspectiveResizeAware perspective;
  RenderProgram progStars;
  RenderProgram progDust;
  Material materialDust;
  Material materialStars;

  late MeshData stars;

  late List<Future<MeshData>> _points_futures;

  // point-clouds
  final List<MeshData> _points = [];
  int currTextIndex = 0;

  // points that will be drawn
  late MeshData _out0;
  late MeshData _out1;

  static const String modelPath = "Assets/Amiga500/amiga500.obj";

  Demo(this.cgl, HTML.CanvasElement canvas, HTML.BodyElement body)
      : camera = OrbitCamera(600.0, 0.0, 0.0, canvas),
        progStars = RenderProgram(
            "basic", cgl, pointSpritesVertexShader, pointSpritesFragmentShader),
        progDust =
            RenderProgram("dust", cgl, dustVertexShader, dustFragmentShader),
        materialStars = Utils.MakeStarMaterial(cgl)
          ..SetUniform(uModelMatrix, VM.Matrix4.identity()),
        materialDust = Material("mat")
          ..SetUniform(uColor, ColorGray8)
          ..SetUniform(uPointSize, 100.0)
          ..SetUniform(
              uModelMatrix,
              VM.Matrix4.identity() //
                ..rotateZ(Math.pi * .5)
                ..rotateY(Math.pi * .5)
                ..rotateX(Math.pi * .45)) {
    perspective = PerspectiveResizeAware(cgl, canvas, camera, 0.1, 2000.0);
    stars = Utils.MakeStarMesh(progDust, 4000, 1000.0);

    var origin = VM.Vector2(0.0, 50.0);

    _points_futures = [
      Future(() => MakePointCloudForText(
          "Commodore Amiga", FONT.font, progDust, origin, LETTER_SCALE * 1.5)),
      MakePointCloudForWaveFrontURL(modelPath, progDust),
      Future(() => MakePointCloudForText(
          "Launched 1985", FONT.font, progDust, origin, LETTER_SCALE)),
      Future(() => MakePointCloudForText(
          "Scener's Best Friends:", FONT.font, progDust, origin, LETTER_SCALE)),
      Future(() => MakePointCloudForText(
          "Agnus, Denise, Paula", FONT.font, progDust, origin, LETTER_SCALE)),
      Future(() => MakePointCloudForText("Beware: Guru Meditation", FONT.font,
          progDust, origin, LETTER_SCALE)),
    ];
  }

  @override
  String name() {
    return "amiga";
  }

  @override
  void Animate(double now, double elapsed, double beat) {
    //camera.azimuth += 0.001;
    camera.animate(elapsed);
    progStars.Draw(stars, [perspective, materialStars]);

    double normalizedTime = (now / 1000.0) % PERIOD;
    double prevNormalizedTime = normalizedTime - elapsed / 1000.0;
    if (prevNormalizedTime < INFLATE_START && normalizedTime >= INFLATE_START) {
      currTextIndex = (currTextIndex + 1) % _points.length;
      print("New TEXT ${currTextIndex}");
    }
    materialDust.ForceUniform(uTime, normalizedTime);

    int bindingIndex = progDust.GetTransformBindingIndex(tPosition);
    cgl.bindBufferBase(
        GL_TRANSFORM_FEEDBACK_BUFFER, bindingIndex, _out0.GetBuffer(aPosition));
    _points[currTextIndex]
        .ChangeAttributeBuffer(aCurrentPosition, _out1.GetBuffer(aPosition));
    progDust.Draw(_points[currTextIndex], [perspective, materialDust]);
    var tmp = _out0;
    _out0 = _out1;
    _out1 = tmp;
  }

  @override
  void Init(List<Future<Object>> loadables) {
    var future = Future.wait(_points_futures)
      ..then((List<MeshData> points) {
        print("Amiga Futures copmpleted");
        Math.Random rand = Math.Random(0);
        Float32List noise = Float32List(NUM_POINTS);
        for (int i = 0; i < NUM_POINTS; ++i) {
          noise[i] = rand.nextDouble();
        }
        for (MeshData md in points) {
          md.AddAttribute(aNoise, noise, 1);
          md.AddAttribute(aCurrentPosition, md.GetAttribute(aPosition), 3);
          _points.add(md);
        }
        _out0 = progDust.MakeMeshData("out", GL_POINTS)
          ..AddVertices(_points[0].GetAttribute(aPosition) as Float32List);
        _out1 = progDust.MakeMeshData("out", GL_POINTS)
          ..AddVertices(_points[0].GetAttribute(aPosition) as Float32List);
      });
    loadables.add(future);
  }

  @override
  double length() {
    return _points_futures.length * PERIOD * 1000.0;
  }
}
