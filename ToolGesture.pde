public class ToolGesture extends Gesture {
  // The new point has to be older than minimumTime and younger than maximum time
  TuioTime minAge = new TuioTime(200);
  TuioTime maxAge = new TuioTime(1500);

  public ToolGesture(ArrayList<TuioCursor> cursors) {
    super(cursors);
  }

  public boolean update() {
    mapManager.useTool(cursors.get(0).getPosition());

    if (cursors.get(0).getTuioState() != TuioCursor.TUIO_REMOVED) {
      return true;
    } else {
      return false;
    }
  }

  public float evaluatePotential() {
    if (mapManager.getTool() == Tool.SPECIAL) {
      return Gesture.NO_MATCH;
    }

    if (cursors.size() != 1) {
      return Gesture.NO_MATCH;
    }

    TuioTime startTime = cursors.get(0).getStartTime();
    TuioTime maxStartTime = TuioTime.getSessionTime().subtract(minAge);
    TuioTime minStartTime = TuioTime.getSessionTime().subtract(maxAge);
    if (startTime.getTotalMilliseconds() <= maxStartTime.getTotalMilliseconds()) {
      if (startTime.getTotalMilliseconds() >= minStartTime.getTotalMilliseconds()) {
        // Try to replicate missed Tool usages
        // This causes a little lag, dependend on the amount of missed points
        for (TuioPoint point : cursors.get(0).getPath()) {
          mapManager.useTool(point);
        }
        return Gesture.MATCH;
      } else {
        return Gesture.NO_MATCH;
      }
    } else {
      return Gesture.UNCLEAR;
    }
  }
}
