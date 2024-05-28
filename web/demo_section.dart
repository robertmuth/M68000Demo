abstract class DemoSection {
  //
  String name();
  //
  void Animate(double now, double elapsed, double beat);
  //
  void Init(List<Future<Object>> loadables) {}
  // The timeline will make "now" go from 0..length.
  // If you run without the timeline, then "now" will just be seconds.
  double length();
}
