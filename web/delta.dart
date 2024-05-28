import 'dart:html' as HTML;
import 'dart:svg' as SVG;
import 'dart:async';

import 'package:chronosgl/chronosgl.dart';
import 'demo_section.dart';
import 'atari_st.dart' as atari_st;
import 'amiga.dart' as amiga;
import 'x68000.dart' as x68000;
import 'macintosh.dart' as macintosh;
import 'm68000.dart' as m68000;
import 'timeline.dart' as timeline;

import 'cube2.dart' as cube2;
import 'effects.dart' as effects;

import 'parameters.dart';

class Hideable {
  final HTML.Element? element;
  Hideable(String id) : element = HTML.document.getElementById(id)! {
    if (element == null) {
      HTML.window.console.error("Missing UI element: ${id}");
    }
  }

  void show() {
    if (element != null) {
      if (element is SVG.SvgElement) {
        element!.style.display = 'inherit';
      } else {
        element!.style.display = 'block';
      }
    }
  }

  void hide() {
    if (element != null) {
      element!.style.display = 'none';
    }
  }
}

final playButton = Hideable('play-button');
final errorOverlay = Hideable('error-overlay');
final iconProgress = Hideable('play-progress');
final iconPlay = Hideable('play-play');

void showError(Object error, StackTrace stack) {
  playButton.hide();
  errorOverlay.show();
  Zone.current.handleUncaughtError(error, stack);
}

void main() {
  playButton.show();
  iconProgress.show();
  // Hack to get redraw.
  HTML.window.animationFrame.then((value) {
    HTML.window.animationFrame.then((value) {
      innerMain();
    }).onError((error, stackTrace) {
      showError(error!, stackTrace);
    });
  });
}

void innerMain() {
  var currentHash = HTML.window.location.hash;
  var parameters = Parameters();
  parameters.decode(currentHash);

  // Set the window location to match the parameters in the parameters object.
  // This should be called after modifying the parameters.
  void updateLocation() {
    var newHash = parameters.encode();
    if (newHash != currentHash) {
      currentHash = newHash;
      HTML.window.location.hash = newHash;
    }
  }

  gLogLevel = 1; // enable more logging
  final StatsFps fps =
      StatsFps(HTML.document.getElementById("fps")!, "blue", "gray");

  final HTML.CanvasElement canvas =
      HTML.document.querySelector('#webgl-canvas') as HTML.CanvasElement;
  final ChronosGL cgl = ChronosGL(canvas);
  final HTML.BodyElement body = HTML.document.body as HTML.BodyElement;
  final HTML.Element section_selectors =
      HTML.document.querySelector('#section_selectors') as HTML.Element;
  final HTML.Element timer =
      HTML.document.querySelector('#timer') as HTML.Element;

// Needed by Atari section
  IntroduceNewShaderVar(
      amiga.aCurrentPosition, const ShaderVarDesc(VarTypeVec3, ""));
  IntroduceNewShaderVar(amiga.aNoise, const ShaderVarDesc(VarTypeFloat, ""));
  IntroduceNewShaderVar(
      effects.uFlameHeight, const ShaderVarDesc(VarTypeFloat, ""));
  IntroduceNewShaderVar(
      effects.uFlameWidth, const ShaderVarDesc(VarTypeFloat, ""));
  IntroduceNewShaderVar(
      effects.uFlameTurbulence, const ShaderVarDesc(VarTypeFloat, ""));
  IntroduceNewShaderVar(
      effects.uFlameThrottle, const ShaderVarDesc(VarTypeFloat, ""));

  IntroduceNewShaderVar(effects.uMode, const ShaderVarDesc(VarTypeFloat, ""));

  IntroduceNewShaderVar("vTexUV2", const ShaderVarDesc(VarTypeVec2, ""));
  IntroduceNewShaderVar(
      "uScreenCoordinates", const ShaderVarDesc(VarTypeMat4, ""));
  IntroduceNewShaderVar("uScreenAspect", const ShaderVarDesc(VarTypeVec2, ""));

  List<DemoSection> sections = [
    m68000.Demo(cgl, canvas, body),
    atari_st.Demo(cgl, canvas, body),
    macintosh.Demo(cgl, canvas, body),
    amiga.Demo(cgl, canvas, body),
    x68000.Demo(cgl, canvas, body),
    cube2.Demo(cgl, canvas, body),
  ];
  final timelineDemo = timeline.Demo(sections);
  sections.insert(0, timelineDemo);

  DemoSection active = sections[0];

  Map<String, DemoSection> sectionsByName = {};
  List<HTML.InputElement> sectionButtons = [];
  for (var s in sections) {
    String name = s.name();
    var id = "radio-${name}";
    var label = HTML.LabelElement()
      ..htmlFor = id
      ..setInnerHtml("&nbsp;&nbsp;${s.name()}");
    var input = HTML.InputElement()
      ..id = id
      ..type = "radio"
      ..name = "demo"
      ..value = name
      ..addEventListener("change", (HTML.Event ev) {
        active = s;
        parameters.section = name;
        updateLocation();
      }, true);
    section_selectors.children.add(label);
    section_selectors.children.add(input);
    sectionsByName[name] = s;
    sectionButtons.add(input);
  }

  List<Future<Object>> loadables = [];
  for (var s in sections) {
    s.Init(loadables);
  }

  double? animStartMs;
  // Main loop body
  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    try {
      if (animStartMs == null) {
        animStartMs = timeMs.toDouble();
        lastTimeMs = animStartMs!;
      }
      double elapsedMs = timeMs.toDouble() - lastTimeMs;
      final beat = elapsedMs * (timeline.tempo / 6e4);
      lastTimeMs = timeMs.toDouble();
      active.Animate(lastTimeMs - animStartMs!, elapsedMs, beat);

      HTML.window.animationFrame.then(animate);
      timer.setInnerHtml("${(lastTimeMs - animStartMs!).toInt()}");
      fps.UpdateFrameCount(lastTimeMs, "extra stiff");
    } catch (e) {
      showError(e, StackTrace.current);
    }
  }

  void start() {
    playButton.hide();
    HTML.window.animationFrame.then(animate);
  }

  int startPos = 0;
  Future.wait(loadables).then((List list) {
    print("Starting Demo");
    if (parameters.debug) {
      start();
      return;
    }
    iconProgress.hide();
    iconPlay.show();
    playButton.element!.addEventListener('click', (HTML.Event event) {
      timelineDemo.startAudio();
      if (parameters.start != 0) {
        startPos = parameters.start;
        timelineDemo.setPos(parameters.start);
      }
      start();
    });
  }).onError((error, stackTrace) {
    showError(error!, stackTrace);
  });

  final HTML.Element controls = HTML.document.getElementById('controls')!;

  // Update the state to match the parameters object.
  void readParameters() {
    final section = sectionsByName[parameters.section] ?? sections[0];

    active = section;
    final name = section.name();
    for (final input in sectionButtons) {
      input.checked = input.value == name;
    }

    controls.style.display = parameters.debug ? 'block' : 'none';

    if (parameters.start != startPos) {
      startPos = parameters.start;
      timelineDemo.setPos(startPos);
    }
  }

  readParameters();

  HTML.window.addEventListener('hashchange', (HTML.Event ev) {
    final newHash = HTML.window.location.hash;
    // This check is here to avoid double updates, where the hash is updated in
    // code.
    if (newHash != currentHash) {
      currentHash = newHash;
      parameters.decode(newHash);
      readParameters();
    }
  });
}
