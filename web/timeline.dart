import 'assets.dart' as assets;
import 'demo_section.dart';

import 'dart:async';
import 'dart:html' as HTML;
import 'dart:web_audio' as Audio;

// Tempo, beats per minute.
const double tempo = 156;

// Seconds of preroll, relative to the start of the first section below.
// This is duration, in the audio file, before the first section starts.
const double preroll = 2 * 60 / tempo;

// Starting points, in measures, in the audio timeline in the DAW.
// These are read directly from the timeline in Logic.
const List<int> markers = [
  5, // Intro, M68000
  25, // Atari ST
  41, // Macintosh
  57, // Amiga
  73, // Sharp
  102, // End
];

// Starting points, in beats, counting from 0 = the first section.
int markerBeat(int index) {
  return 4 * markers[index];
}

// Calculate section number, given the timestamp in beats.
int findSection(double beat) {
  for (int i = 0; i < markers.length - 2; i++) {
    final end = markerBeat(i + 1);
    if (beat < end) {
      return i;
    }
  }
  return markers.length - 2;
}

class Demo extends DemoSection {
  final HTML.AudioElement soundtrack;
  final List<DemoSection> sections;
  Audio.AudioContext? context;
  Audio.MediaElementAudioSourceNode? source;
  int currentSection = 0;
  double lastRelativeTime = 0.0;
  bool playing = false;

  Demo(List<DemoSection> sections)
      : soundtrack =
            HTML.AudioElement(assets.getURL('Assets/music.opus', 'audio/ogg'))
              ..preload = 'auto',
        sections = List.from(sections);

  @override
  void Animate(double now, double elapsed, double dummyBeatDontUse) {
    if (!playing) {
      return;
    }
    // Fallback to the animation clock if the soundtrack is not playing.
    final audioTime =
        source != null ? soundtrack.currentTime as double : now * 0.001;
    // Beat, relative to the start of audio timeline in DAW.
    final beat = (audioTime - preroll) * (tempo / 60) + 4 * markers[0];
    final index = findSection(beat);
    if (currentSection != index) {
      currentSection = index;
      lastRelativeTime = 0.0;
    }
    final start = markerBeat(index);
    final end = markerBeat(index + 1);
    final actualLength = end - start;
    final section = sections[index];
    final expectedLength = section.length();
    var relativeTime = (beat - start) * (expectedLength / actualLength);
    if (relativeTime < 0) {
      relativeTime = 0;
    } else if (relativeTime > expectedLength) {
      relativeTime = expectedLength;
    }
    final relativeElapsed = relativeTime - lastRelativeTime;
    lastRelativeTime = relativeTime;
    section.Animate(relativeTime, relativeElapsed, beat - start);
  }

  @override
  String name() {
    return 'timeline';
  }

  void startAudio() {
    if (context != null) {
      return;
    }
    try {
      final newContext = Audio.AudioContext();
      final newSource = newContext.createMediaElementSource(soundtrack);
      newSource.connectNode(newContext.destination!);
      soundtrack.onPlaying.listen((event) {
        playing = true;
      });
      soundtrack.play();
      context = newContext;
      source = newSource;
    } catch (e) {
      playing = true;
      HTML.window.console.error(e);
    }
  }

  @override
  double length() {
    // Dummy value.
    return 1000;
  }

  // Set the current position, in measures.
  void setPos(int pos) {
    if (source != null) {
      soundtrack.currentTime = (pos - markers[0]) * 4 * (60 / tempo) + preroll;
    }
  }
}
