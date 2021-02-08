public class SizeAdjustmentGesture extends Gesture { //<>// //<>// //<>// //<>// //<>//
  float initialDistance;
  TuioPoint initialPosition;
  TuioTime initialTime;
  float initialAngle;
  float lastAngle;
  
  // Matching timeout (ms)
  //TuioTime timeout = new TuioTime(1500);
  // Minimal start distance (mm)
  float minimum_distance = 50;
  // Maximum start distance (mm)
  float maximum_distance = 150;
  // Maximum distance change before impossible (mm)
  float distance_change_threshold = 10;
  // Maximum position change before impossible (mm)
  float position_change_threshold = 10;
  boolean initialized = false;


  float angle_threshold = 10;
  // How much each degree changes the brush size (mm)
  float angle_to_size = 1;

  public SizeAdjustmentGesture(ArrayList<TuioCursor> cursors) {
    super(cursors);
  }

  public boolean update() {
    float currentAngle = cursors.get(0).getAngleDegrees(cursors.get(1));
    float angleChange = angleDifference(currentAngle, lastAngle);
    lastAngle = currentAngle;
    adjustSizeByAngle(angleChange);
    stroke(#000000);
    fill(color(0, 0, 50, 128));
    circle(initialPosition.getScreenX(width), initialPosition.getScreenY(height),mapManager.getBrushSize()/screen_pixel_width);

    if (cursors.get(0).getTuioState() == TuioCursor.TUIO_REMOVED || cursors.get(1).getTuioState() == TuioCursor.TUIO_REMOVED) {
      return false;
    }
    return true;
  }
  
  public void adjustSizeByAngle(float angle){
    mapManager.changeBrushSize(angle*angle_to_size/screen_pixel_width);
  }

  public float evaluatePotential() {
    if (cursors.size() != 2) {
      println("wrong size");
      return Gesture.NO_MATCH;
    }

    // Abort if one cursor is removed
    if (cursors.get(0).getTuioState() == TuioCursor.TUIO_REMOVED || cursors.get(1).getTuioState() == TuioCursor.TUIO_REMOVED) {
      println("removed");
      return Gesture.NO_MATCH;
    }

    float currentAngle = cursors.get(0).getAngleDegrees(cursors.get(1));
    float currentDistance = getTouchDistance(cursors.get(0), cursors.get(1));
    TuioPoint currentPosition = getMiddle(cursors.get(0),cursors.get(1));
    TuioTime currentTime = TuioTime.getSessionTime();

    if (!initialized) {
      initialDistance = currentDistance;
      initialAngle = currentAngle;
      initialPosition = currentPosition;
      println(initialPosition.getX());
      initialTime = currentTime;
      initialized = true;
      if (initialDistance < minimum_distance || initialDistance > maximum_distance) {
        println("initialDistance");
        return Gesture.NO_MATCH;
      }
    }

    float positionChange =  getTouchDistance(initialPosition, currentPosition);
    if( positionChange > position_change_threshold ){
      println("position changed too much");
      return Gesture.NO_MATCH;
    }

    float distanceChange = abs(currentDistance-initialDistance);
    if (distanceChange >= distance_change_threshold) {
      println("distance changed too much");
      return Gesture.NO_MATCH;
    }

    if (abs(angleDifference(initialAngle,currentAngle)) > angle_threshold) {
      println("match");
      lastAngle = currentAngle;
      return Gesture.MATCH;
    }
    
    //if( currentTime.subtract(timeout).getTotalMilliseconds() > initialTime.getTotalMilliseconds()){
    //  println("timeout");
    //  return Gesture.NO_MATCH;
    //}

    return Gesture.UNCLEAR;
  }
  
  // Calculate the angle difference. the result is between -180 and +180
  float angleDifference(float angleA, float angleB){
    float angleChange = (((angleA-angleB)%360)+360)%360;
    if( angleChange > 180 ){
      angleChange = -360+angleChange;
    }
    return angleChange;
  }
}
