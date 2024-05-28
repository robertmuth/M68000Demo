import 'package:chronosgl/chronosgl.dart';

const String uFlameHeight = "uFlameHeight";
const String uFlameWidth = "uFlameWidth";
const String uFlameTurbulence = "uFlameTurbulence";
const String uFlameThrottle = "uFlameThrottle";
const String uMode = "uMode";

const int DIM = 512;

final ShaderObject VertexShader = ShaderObject("nullShaderV")
  ..AddAttributeVars([aPosition])
  ..SetBody([
    """void main() {
  gl_Position = vec4(${aPosition}, 1.0);
}"""
  ]);

final ShaderObject FragmentShader = ShaderObject("fireShaderF")
  ..AddUniformVars([
    uTexture,
    uFlameThrottle,
    uFlameWidth,
    uFlameHeight,
    uFlameTurbulence,
    uTime,
    uMode,
  ])
  ..SetBody([
    ColorFunctions,
    """
#define PI 3.1415926536

// ===============================================================
// 
// ===============================================================

float rand(vec2 xy){
    return fract(sin(dot(xy ,vec2(12.9898,78.233))) * 43758.5453);
}
    
float get(vec2 xy) {
    vec2 DIM = vec2(textureSize(${uTexture}, 0));  
    return texture(${uTexture}, xy / DIM).a;
}
float Fire(vec2 xy) {
    if (xy.y < 1.0) {
        float r = rand(vec2(${uTime}, xy.x));
        return get(xy) + (r - 0.5) * ${uFlameTurbulence}; 
    }
    
    float height = ${uFlameHeight};
    float width =  ${uFlameWidth};
    return (4.0 * get(xy) +
            get(xy + vec2(0.0, -height)) +
            get(xy + vec2(-width,  -height)) +
            get(xy + vec2(width,  -height)) +
            get(xy + vec2(0.0, -2.0 * height))) * ${uFlameThrottle} * 0.5;
}

// ===============================================================
// https://www.shadertoy.com/view/4dBXRt  (portion of next demo)
// ===============================================================

vec3 Rasterbars(vec2 uv, float time) {
    float gr = uv.y;
    float rx = floor(sin(gr * 15.0) + sin(gr * 25.0 - 3.0 * time) * 4.0);
    float ry = floor(sin(gr * 25.0 + time) + sin(gr * 35.0 + 4.0 * time) * 4.0);
    float rz = floor(sin(gr * 45.0) + sin(gr * 20.0 + sin(gr * 30.0 + 2.0 * time)) * 4.0);
    return vec3(rx, ry, rz) * 0.2;
}
// ===============================================================
// https://www.shadertoy.com/view/ldBGRR
// ===============================================================

vec3 Plasma(vec2 uv, float time) { 
  vec2 p = -1.0 + 2.0 * uv;
  // main code, *original shader by: 'Plasma' by Viktor Korsun (2011)
  float x = p.x;
  float y = p.y;
  float mov0 = x+y+cos(sin(time)*2.0)*100.+sin(x/100.)*1000.;
  float mov1 = y / 0.9 +  time;
  float mov2 = x / 0.2;
  float c1 = abs(sin(mov1+time)/2.+mov2/2.-mov1-mov2+time);
  float c2 = abs(sin(c1+sin(mov0/1000.+time)+sin(y/40.+time)+sin((x+y)/100.)*3.));
  float c3 = abs(sin(c2+cos(mov1+mov2+c2)+cos(mov2)+sin(x/1000.)));
  return vec3(c1,c2,c3);
}


// ===============================================================
// https://www.shadertoy.com/view/4ssGWn
// ===============================================================

vec3 AmigaBall(vec2 uv, float time) {
    const vec2 res = vec2(320.0,200.0);
    const mat3 mRot = mat3(0.9553, -0.2955, 0.0, 0.2955, 0.9553, 0.0, 0.0, 0.0, 1.0);
    const vec3 ro = vec3(0.0,0.0,-4.0);

    const vec3 cRed = vec3(1.0,0.0,0.0);
    const vec3 cWhite = vec3(1.0);
    const vec3 cGrey = vec3(0.66);
    const vec3 cPurple = vec3(0.51,0.29,0.51);

    const float maxx = 0.378;

    float asp = 1.0;
    vec2 uvR = floor(uv*res);
    vec2 g = step(2.0,mod(uvR,16.0));
    vec3 bgcol = mix(cPurple,mix(cPurple,cGrey,g.x),g.y);
    uv = uvR/res;
    float xt = mod(time+1.0,6.0);
    float dir = (step(xt,3.0)-.5)*-2.0;
    uv.x -= (maxx*2.0*dir)*mod(xt,3.0)/3.0+(-maxx*dir);
    uv.y -= abs(sin(4.5+time*1.3))*0.5-0.3;
    bgcol = mix(bgcol,bgcol-vec3(0.2),1.0-step(0.12,length(vec2(uv.x,uv.y*asp)-vec2(0.57,0.29))));
    vec3 rd = normalize(vec3((uv*2.0-1.0)*vec2(1.0,asp),1.5));
    float b = dot(rd,ro);
    float t1 = b*b-15.6;
    float t = -b-sqrt(t1);
    vec3 nor = normalize(ro+rd*t)*mRot;
    vec2 tuv = floor(vec2(atan(nor.x,nor.z)/PI+((floor((time*-dir)*60.0)/60.0)*0.5),acos(nor.y)/PI)*8.0);
    return mix(bgcol,mix(cRed,cWhite,
                          clamp(mod(tuv.x+tuv.y,2.0),0.0,1.0)),1.0-step(t1,0.0));
}

// ===============================================================
//
// ===============================================================
// http://paulbourke.net/fractals/mandelbrot/
const vec2 mandel_center1 = vec2(-0.761574,-0.0847596);
const vec2 mandel_center2 = vec2(-0.13856524454488, -0.64935990748190);
const vec2 mandel_center3 = vec2(0.42884, -0.231345);
const vec2 mandel_center4 = vec2(-1.001105, -0.300717);

const int kMaxIterations = 300;

int mandelbrot(vec2 uv) {
    vec2 z = uv;
    for (int i = 0; i < kMaxIterations; i++) {
        if (dot(z, z) > 4.0) return i;
        // z = z^2 + uv
        z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + uv;
    }
    return 0;
}

vec3 Fractal(vec2 uv, float time) {
    float t  = mod(time, 50.0);  // repeat after 50s
    vec2 xy = mandel_center4 + (uv - vec2(0.5)) / pow(1.2, t);
    float ret = float(mandelbrot(xy));
    
    return cos((6.3 - ret * 0.006) * vec3(4.0,2.0,1.0));
}

// ===============================================================
// https://www.shadertoy.com/view/4sKBWW
// ===============================================================

float circ( vec2 uv, vec2 cPos, float cSize ) {
    return 1.0-smoothstep(0.0, cSize, length(uv-cPos))/cSize;
}

float ring( vec2 uv, vec2 rPos, float rSize ) {
    const float NUM_DOTS_IN_RING = 64.0;

    const float MAGIC_CONST = ((2.0*PI)/NUM_DOTS_IN_RING);
    const float DOT_SIZE = 0.1;

    //center ourselves about the ring
    vec2 myPos = uv - rPos;
    
    //some polar fun
    float angle = atan(myPos.y, myPos.x);
    
    float c = MAGIC_CONST;
    float nearestAngle = c*round(angle/c);
    //return vec3(nearestAngle/(2.0*PI));
    vec2 nearestDotPos;
    nearestDotPos.x = cos(nearestAngle)*rSize;
    nearestDotPos.y = sin(nearestAngle)*rSize;

    float dotSize = DOT_SIZE;
    return circ(myPos, nearestDotPos, dotSize);
}

vec3 Tunnel(vec2 uv, float time) {
    const int NUM_RINGS = 64;   // use more than are visible to 
    const float RING_SCALE = 0.05;
    const float EPSILON = 0.00001;
    const float BASE_SIZE = 0.001;
    const float SPEED = 8.0;

    uv -= 0.5;
    uv *= 2.0;
    
    float scaledTime = SPEED*time;
    float scale = fract(scaledTime);

    float col;
    
    for(int i = NUM_RINGS+1; i > 0; i--) {
        float fi = float(i);

        float size = (fi+scale)*RING_SCALE+BASE_SIZE;
        float ringNum = scale+fi;
        float move = (time+ringNum/16.0);
        vec2 center = vec2(cos(move*0.7)*1.5, sin(cos(move)*2.5)*0.5);
        col = ring(uv, center, size);
        //float col = ring(uv, vec2(0.0), size);
        if(col > EPSILON) {
            float colRange = mod((scaledTime-fi), 8.0);
            col /= 1.0+float(colRange < 4.0);
            break;
        }
    }
    return vec3(col);
}

// ===============================================================
//
// ===============================================================

/*
      "                ",
      "     * ** *     ",
      "     * ** *     ",
      "     * ** *     ",
      "     * ** *     ",
      "    ** ** **    ",
      "    ** ** **    ",
      "   *** ** ***   ",
      "  ***  **  ***  ",
      " ****  **  **** ",
      " ***   **   *** ",
      " ***   **   *** ",
      " **    **    ** ",
      " *     **     * ",
      "                ",
      "                ",
*/

const int kAtariLogo[16] = int[16](
  0x0,
  0x5a0,
  0x5a0,
  0x5a0,
  0x5a0,
  0xdb0,
  0xdb0,
  0x1db8,
  0x399c,
  0x799e,
  0x718e,
  0x718e,
  0x6186,
  0x4182,
  0x0,
  0x0);

const vec3 kBackgroundColor = vec3(1.,0.,0.);
const vec3 kGridColor = vec3(0.,0.,0.);

mat2 RotationMatrix(float a){
    float s = sin(a);
    float c = cos(a);
    return mat2(c,-s,s,c);
}

// cell range is -.5  to  +.5
vec3 MakeLogo(vec2 uv_cell, vec3 fg, vec3 bg) {
  // iuv should range from 0-5
  ivec2 iuv = ivec2(floor( (uv_cell * 2.0 + vec2(0.5)) * 16.0));
  if (iuv.x < 0 || iuv.x > 15 || iuv.y < 0 || iuv.y > 16) return bg;
  int row = kAtariLogo[iuv.y];
  return ((row >> iuv.x) & 1) == 0 ? bg : fg;
}

vec3 RotoZoom(vec2 uv, float time) {
    // rotate image
    vec2 uv_rot = uv * RotationMatrix(time);
    // scale it saw-toothh style
    vec2 uv_scaled = uv_rot * 10.0 * (abs(fract(time)-.5)+0.2);
    //
    vec2 uv_cell=fract(uv_scaled)-.5;

  vec3 col = kBackgroundColor ;


  // Put the logo only into every other cell
  if(mod(floor(uv_scaled.x),2.) != mod(floor(uv_scaled.y),2.) ) {
    col += MakeLogo(uv_cell, vec3(1.0), kBackgroundColor);
  }

  if(abs(uv_cell.x) > .48 || abs(uv_cell.y) >.48) col = kGridColor;
  return col;
}


vec3 Plasma4(vec2 uv, float time) {
	vec2 p = 5.0 * uv;

    vec4 a = vec4(.1,.4,.222,0) + time + atan(p.y, p.x), 
         b = a; b.y+=.4;
    a = cos( sin(p.x)-cos(p.y) +a ),
    b = sin( a*p.x*p.y - p.y   +b );

    a =  abs(b*b-a*a);

    return  1.6 * pow(1.-a+a*a,  16.+a-a).rgb;
}


// also worth checking out:
// https://www.shadertoy.com/view/XsS3DV metaballs
// https://www.shadertoy.com/view/7tcGzn car race
// https://www.shadertoy.com/view/7lcSzX roto zoom
// https://www.shadertoy.com/view/wsKSRG copper bars
// https://www.shadertoy.com/view/XlyXWK many elements in one
// https://www.shadertoy.com/view/4dBXRt cool raster bars (drop non rasterbar part)
// https://www.shadertoy.com/view/MlSSR3 raster bars
// https://www.shadertoy.com/view/lsfGzr plasma
// https://www.shadertoy.com/view/4lsGDl plasma
// https://www.shadertoy.com/view/MdsXDM plasma

vec3 RgbToGray(vec3 color) {
  return vec3(0.21 * color.r + 0.71 * color.g + 0.07 * color.b);
}

void main() {
    vec2 uv = gl_FragCoord.xy / float(${DIM});

    // coordinates will be between 0.0 and 1.0
    if (${uMode} == 1.0) {

      float v = Fire(gl_FragCoord.xy);
      ${oFragColor}.a = v;
      vec3 hsl = vec3(v / 3.0, 1.0, clamp(2.0 * v, 0.0, 1.0));
      ${oFragColor}.rgb = HSLtoRGB(hsl);
    } else if (${uMode} == 2.0) {
      ${oFragColor}.rgb =  Rasterbars(uv, ${uTime} / 1000.0); 
    } else if (${uMode} == 3.0) {
      ${oFragColor}.rgb = Tunnel(uv, ${uTime} / 1000.0);
    } else if (${uMode} == 4.0) {
      ${oFragColor}.rgb = Plasma(uv, ${uTime} / 1000.0);
    } else if (${uMode} == 25.0) {
      ${oFragColor}.rgb = Plasma4(uv, ${uTime} / 1000.0);
    } else if (${uMode} == 10.0) {
      ${oFragColor}.rgb = RotoZoom(uv, ${uTime} / 1000.0);
    } else if (${uMode} == 11.0) {
      ${oFragColor}.rgb = Fractal(uv, ${uTime} / 1000.0);
    } else if (${uMode} == 12.0) {
      ${oFragColor}.rgb = RgbToGray(AmigaBall(uv, ${uTime} / 1000.0));
    } else if (${uMode} == 13.0) {
      ${oFragColor}.rgb = RgbToGray(Fractal(uv, ${uTime} / 1000.0));
    } else if (${uMode} == 14.0) {
      ${oFragColor}.rgb = RgbToGray(RotoZoom(uv, ${uTime} / 1000.0));
    } else {
      ${oFragColor}.rgb = AmigaBall(uv, ${uTime} / 1000.0);
    }
}
"""
  ]);

TypedTextureMutable MakeStateTexture(
        String name, ChronosGL cgl, int w, int h, bool wrapped) =>
    TypedTextureMutable(
        cgl,
        name,
        w,
        h,
        GL_RGBA,
        wrapped
            ? TexturePropertiesFramebufferWrapped
            : TexturePropertiesFramebuffer,
        GL_RGBA,
        GL_UNSIGNED_BYTE,
        null);

class OldSchool {
  final RenderProgram _progFire;
  final List<TypedTextureMutable> _textures;
  final Material _materialFire;
  late List<Framebuffer> _fbs;
  late MeshData _unit;
  int _frameCount = 0;

  OldSchool(cgl)
      : _progFire = RenderProgram("fire", cgl, VertexShader, FragmentShader),
        _textures = [
          MakeStateTexture("s0", cgl, DIM, DIM, false),
          MakeStateTexture("s1", cgl, DIM, DIM, false)
        ],
        _materialFire = Material("cube")
          ..ForceUniform(uFlameTurbulence, 0.3)
          ..ForceUniform(uFlameHeight, 4.5)
          ..ForceUniform(uFlameWidth, 2.5)
          ..ForceUniform(uFlameThrottle, 0.247) // needs to smaller than 1/4.0,
  {
    _fbs = [Framebuffer(cgl, _textures[0]), Framebuffer(cgl, _textures[1])];
    _unit = ShapeQuad(_progFire, 1);
  }

  TypedTextureMutable RenderTexture(double timeMs) {
    ++_frameCount;
    _materialFire.ForceUniform(uTime, timeMs);
    if (_frameCount % 2 == 0) {
      _fbs[1].Activate(GL_CLEAR_ALL, 0, 0, DIM, DIM);
      _materialFire.ForceUniform(uTexture, _textures[0]);
      _progFire.Draw(_unit, [_materialFire]);
      return _textures[0];
    } else {
      _fbs[0].Activate(GL_CLEAR_ALL, 0, 0, DIM, DIM);
      _materialFire.ForceUniform(uTexture, _textures[1]);
      _progFire.Draw(_unit, [_materialFire]);
      return _textures[1];
    }
  }

  void SwitchMode(double mode) {
    _materialFire.ForceUniform(uMode, mode);
  }
}
