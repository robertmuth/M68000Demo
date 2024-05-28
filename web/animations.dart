import 'dart:html' as HTML;
import 'effects.dart' as effects;

import 'package:chronosgl/chronosgl.dart';

const int TEXTURE_W = 512;
const int TEXTURE_H = 512;

abstract class Animation {
  Animation(this.duration);
  final double duration;

  Texture? Render(double now, double elapsed);

  void Init() {}

  void Fini() {}
}

class NullAnimation extends Animation {
  NullAnimation(super.duration);

  @override
  Texture? Render(double now, double elapsed) {
    return null;
  }
}

class FixedAnimation extends Animation {
  final Texture _texture;

  FixedAnimation(super.duration, this._texture);

  @override
  Texture? Render(double now, double elapsed) {
    return _texture;
  }
}

const String CURSOR = "■";

class TextState {
  TextState(this.text);

  final String text;
  int pos = -1;
  bool showCursor = false;
  int count = 0;

  void Reset() {
    pos = -1;
    showCursor = false;
    count = 0;
  }

  String nextText() {
    showCursor = (count % 30) < 20;
    if (pos == text.length) {
      // do nothing
    } else if (pos == -1) {
      for (int i = 0; i < text.length; i++) {
        var c = text[i];
        if (c != '\n') {
          pos = i;
          break;
        }
      }
    } else if ((count % 10) < 8) {
      for (int i = pos + 1; i < text.length; i++) {
        var c = text[i];
        if (c != '\n') {
          pos = i;
          break;
        } else if (i == text.length - 1) {
          pos = text.length;
        }
      }
    }

    ++count;
    String s = text.substring(0, pos);
    if (showCursor) {
      s += CURSOR;
    }
    return s;
  }
}

class TextAnimation extends Animation {
  final ImageTexture screenTexture;

  final canvas = HTML.CanvasElement(width: TEXTURE_W, height: TEXTURE_H);
  final TextState _textState;
  TextAnimation(super.duration, text, this.screenTexture)
      : _textState = TextState(text);

  @override
  Texture? Render(double now, double elapsed) {
    var ctx = canvas.getContext('2d') as HTML.CanvasRenderingContext2D;
    ctx.clearRect(0, 0, canvas.width!, canvas.height!);
    ctx.fillStyle = "#24cc44";
    ctx.font = "30px vt323, monospace";
    // ctx.fillStyle = "#41FF00";
    int y = 200;

    for (String line in _textState.nextText().split("\n")) {
      ctx.fillText(line, 10, y);
      y += 50;
    }
    screenTexture.SetImageData(canvas);
    return screenTexture;
  }

  @override
  void Init() {
    _textState.Reset();
  }
}

class MacTextAnimation extends Animation {
  final ImageTexture screenTexture;

  final canvas = HTML.CanvasElement(width: TEXTURE_W, height: TEXTURE_H);
  final TextState _textState;
  MacTextAnimation(super.duration, text, this.screenTexture)
      : _textState = TextState(text);

  @override
  Texture? Render(double now, double elapsed) {
    var ctx = canvas.getContext('2d') as HTML.CanvasRenderingContext2D;
    ctx.clearRect(0, 0, canvas.width!, canvas.height!);
    ctx.fillStyle = "white";
    double radius = 20.0;
    double x = 0.0;
    double y = 140.0;
    var w = canvas.width!;
    var h = canvas.height! - y;
    var r = x + w;
    var b = y + h;
    HTML.Path2D path = HTML.Path2D();
    path.moveTo(x + radius, y);
    path.lineTo(r - radius, y);
    path.quadraticCurveTo(r, y, r, y + radius);
    path.lineTo(r, y + h - radius);
    path.quadraticCurveTo(r, b, r - radius, b);
    path.lineTo(x + radius, b);
    path.quadraticCurveTo(x, b, x, b - radius);
    path.lineTo(x, y + radius);
    path.quadraticCurveTo(x, y, x + radius, y);
    ctx.fill(path);
    ctx.fillStyle = "black";
    ctx.font = "40px macclassic";
    // ctx.fillStyle = "#41FF00";
    int row = 200;

    for (String line in _textState.nextText().split("\n")) {
      ctx.fillText(line, 10, row);
      row += 50;
    }
    screenTexture.SetImageData(canvas);
    return screenTexture;
  }
}

class OldSkoolAnimation extends Animation {
  double _mode;
  effects.OldSchool _effect;
  OldSkoolAnimation(super.duration, this._mode, this._effect);

  @override
  Texture? Render(double now, double elapsed) {
    _effect.SwitchMode(_mode);
    return _effect.RenderTexture(now);
  }
}

class RotateAnimation extends Animation {
  RotateAnimation(super.duration, this._angle, this._camera,
      {double? force_start})
      : _force_start = force_start;
  final double _angle;
  final OrbitCamera _camera;
  final double? _force_start;

  @override
  Texture? Render(double now, double elapsed) {
    final double time_diff = duration - now - elapsed;
    final double angle_diff = _angle - _camera.azimuth;

    if (elapsed < 0) {
      print("elapsed < 0");
    }
    if (now >= duration) {
      _camera.azimuth = _angle;
      print("animation completed");
      return null;
    }
    if (angle_diff < 0) {
      print("negative ${angle_diff}  ${time_diff}  ${now}  ${elapsed}");
      return null;
    }
    _camera.azimuth += angle_diff * elapsed / time_diff;
    if (_camera.azimuth > _angle) _camera.azimuth = _angle;
    return null;
  }

  @override
  void Init() {
    if (_force_start != null) _camera.azimuth = _force_start!;
  }

  @override
  void Fini() {
    print("finalize roation: ${_camera.azimuth} ${_angle}");
    _camera.azimuth = _angle;
  }
}

class AnimationSequence {
  AnimationSequence(this._sequence) {
    for (Animation s in _sequence) {
      _duration += s.duration;
    }
    assert(_duration > 0.0);
  }

  final List<Animation> _sequence;
  double _duration = 0.0;

  double Duration() {
    return _duration;
  }

  Texture? Run(double now, double elapsed) {
    if (now >= _duration) {
      now = _duration - 0.0001;
    }

    double start = 0;

    for (Animation anim in _sequence) {
      final double end = start + anim.duration;
      final double last = now - elapsed;
      if (last <= end && end <= now) {
        // finish previous anim
        // print("anim fini ${anim}");
        anim.Fini();
      }

      if (start <= now && now <= end) {
        if (last < start) {
          //print(
          //    "anim init ${anim} now=${now} elapsed=${elapsed} start=${start}");
          elapsed = now - start;
          anim.Init();
        }
        return anim.Render(now - start, elapsed);
      }
      start += anim.duration;
    }
    return null;
  }
}
