import TUIO.*; //<>//
import java.util.Map;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.Random;
// declare a TuioProcessing client
TuioProcessing tuioClient;

// these are some helper variables which are use
float cursor_size = 15;
float object_size = 60;
float table_size = 760;
float scale_factor = 1;
PFont font;

boolean doDebugOverlay = true;

public abstract class Gesture {
  public static final float NO_MATCH = 0.0f;
  public static final float UNLIKELY = 0.25f;
  public static final float UNCLEAR = 0.5f;
  public static final float LIKELY = 0.75f;
  public static final float MATCH = 1.0f;
  ArrayList<TuioCursor> cursors;

  public ArrayList<TuioCursor> getCursors() {
    return cursors;
  }

  public Gesture(ArrayList<TuioCursor> cursors) {
    this.cursors = cursors;
  }

  // As long as the gesture is a match update is called
  // You signal the end of the gesture, by returning false
  public abstract boolean update();

  // A potential of 0 means, that the cursors cannot represent this Gesture and it can be deleted
  // A potential between 0 and 1 means, that the cursors could be this gesture
  // A potential of 1 means, that the cursors represent this gesture
  // As soon as the value is one evaluate Potential is no longer called
  public abstract float evaluatePotential();
}

public class ToolGesture extends Gesture {
  //The new point has to be older than minimumTime and younger than maximum time
  TuioTime minAge = new TuioTime(1000);
  TuioTime maxAge = new TuioTime(10000);

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
    if (cursors.size() != 1) {
      return Gesture.NO_MATCH;
    }

    TuioTime startTime = cursors.get(0).getStartTime();
    TuioTime maxStartTime = TuioTime.getSessionTime().subtract(minAge);
    TuioTime minStartTime = TuioTime.getSessionTime().subtract(maxAge);
    if (startTime.getTotalMilliseconds() <= maxStartTime.getTotalMilliseconds()) {
      if (startTime.getTotalMilliseconds() >= minStartTime.getTotalMilliseconds()) {
        return Gesture.MATCH;
      } else {
        return Gesture.NO_MATCH;
      }
    } else {
      return Gesture.UNCLEAR;
    }
  }
}

public class PinchGesture extends Gesture {
  //The new point has to be older than minimumTime and younger than maximum time
  TuioTime minAge = new TuioTime(100);
  TuioTime maxAge = new TuioTime(1000);
  float initialDistance;
  float initialAngle;
  boolean initialized = false;

  float angleThreshold = 30.0;
  float distanceThreshold = 0.1;

  public PinchGesture(ArrayList<TuioCursor> cursors) {
    super(cursors);
  }

  int menu = -1;

  public boolean update() {

    updateMenu();

    if (cursors.get(0).getTuioState() != TuioCursor.TUIO_REMOVED || cursors.get(1).getTuioState() != TuioCursor.TUIO_REMOVED) {
      return true;
    } else {
      return false;
    }
  }

  public float evaluatePotential() {
    if (cursors.size() != 2) {
      return Gesture.NO_MATCH;
    } else {
      if (cursors.get(0).getTuioState() == TuioCursor.TUIO_REMOVED || cursors.get(1).getTuioState() == TuioCursor.TUIO_REMOVED) {
        return Gesture.NO_MATCH;
      }
      if (!initialized) {
        initialDistance =  cursors.get(0).getDistance(cursors.get(1));
        initialAngle = cursors.get(0).getAngleDegrees(cursors.get(1));
        initialized = true;
        return Gesture.UNCLEAR;
      } else {
        float currentAngle = cursors.get(0).getAngleDegrees(cursors.get(1));
        float currentDistance = cursors.get(0).getDistance(cursors.get(1));
        if (abs(abs(currentAngle)-abs(initialAngle)) < angleThreshold) {
          float travelledDistance = abs(currentDistance) - abs(initialDistance);
          if (abs(travelledDistance) > distanceThreshold && travelledDistance < 0) { // Making sure minimum distance travelled towards each other is met
            // TODO: Add min and max time
            return Gesture.MATCH;
          } else {
            return Gesture.UNCLEAR;
          }
        } else {
          return Gesture.NO_MATCH;
        }
      }
    }
  }

  boolean menuePosSet = false;
  TuioPoint menuePos;
  int menueX;
  int menueY;

  public void updateMenu() {
    if (menu < 0) {
      if (cursors.get(0).getTuioState() == TuioCursor.TUIO_REMOVED) {
        menu = 1;
      } else if (cursors.get(1).getTuioState() == TuioCursor.TUIO_REMOVED) {
        menu = 0;
      }
    
    // Start menueing
    } else {
      //println("Opening menue");
      TuioCursor menueCursor = cursors.get(menu);

      if (!menuePosSet) { //<>//
        menuePos = menueCursor.getPosition();
        menueX = menueCursor.getScreenX(width);
        menueY = menueCursor.getScreenY(height);
        menuePosSet = true;
      }

      // TODO: show actual menue
      if (doDebugOverlay) {
        stroke(0, 255, 0);
        line(menueX - 300, menueY, menueX + 300, menueY);
        line(menueX, menueY - 300, menueX, menueY + 300);
        
        image(buttons.get("Raise")[0], 100, 100);
        image(buttons.get("Lower")[1], 220, 100);
        image(buttons.get("Smooth")[2], 340, 100);
      }
      if (cursors.get(0).getTuioState() == TuioCursor.TUIO_REMOVED && cursors.get(1).getTuioState() == TuioCursor.TUIO_REMOVED) {
        float menueChoosenAngle = menuePos.getAngleDegrees(menueCursor.getPosition());
        if (menueChoosenAngle > 0 && menueChoosenAngle < 90) {mapManager.changeTool(Tool.RAISE_TERRAIN);}
        else if (menueChoosenAngle < 180) {mapManager.changeTool(Tool.LOWER_TERRAIN);}
        else if (menueChoosenAngle < 270) {mapManager.changeTool(Tool.BLUR_TERRAIN);}
        else {}
        println("Closing menue: " + menueChoosenAngle + " and changed Tool to: " + mapManager.tool.toString());
      }
    }
  }
}

public class ScrollGesture extends Gesture {
  //The new point has to be older than minimumTime and younger than maximum time
  TuioTime minAge = new TuioTime(100);
  TuioTime maxAge = new TuioTime(1000);
  float initialDistance;
  TuioPoint initialDirtyPos;
  TuioPoint initialPos;
  boolean initialized = false;

  float angleThreshold = 20; // Eg. 80°-100° = brushSize up 
  float distanceDeviationThreshold = 0.05;
  float distanceThreshold = 0.05;
  
  int stepMod = 300;  // TODO: Somehow rework the step system to be nicer
  
  public ScrollGesture(ArrayList<TuioCursor> cursors) {
    super(cursors);
  }

  public boolean update() {

    updateScrollActions();

    if (cursors.get(0).getTuioState() != TuioCursor.TUIO_REMOVED && cursors.get(1).getTuioState() != TuioCursor.TUIO_REMOVED) {
      return true;
    } else {
      return false;
    }
  }

  public float evaluatePotential() {
    if (cursors.size() != 2) { //<>//
      return Gesture.NO_MATCH;
    } else {
      if (cursors.get(0).getTuioState() == TuioCursor.TUIO_REMOVED || cursors.get(1).getTuioState() == TuioCursor.TUIO_REMOVED) {
        return Gesture.NO_MATCH;
      }
      if (!initialized) {
        initialDistance = cursors.get(0).getDistance(cursors.get(1));
        initialDirtyPos = cursors.get(0).getPosition();
        initialPos = calcPosBetween(initialDirtyPos, cursors.get(1).getPosition());
        initialized = true;
        return Gesture.UNCLEAR;
      } else {
        float currentDistance = cursors.get(0).getDistance(cursors.get(1));
        //println("Distance travelled: " + cursors.get(0).getDistance(initialDirtyPos) + "   Deviation: " + abs(initialDistance - currentDistance));
        if (abs(initialDistance - currentDistance) < distanceDeviationThreshold) {
          float travelledDistance = cursors.get(0).getDistance(initialDirtyPos);
          if (abs(travelledDistance) > distanceThreshold) { // Making sure minimum distance travelled together is met
            // TODO: Add min and max time
            return Gesture.MATCH;
          } else {
            return Gesture.UNCLEAR;
          }
        } else {
          return Gesture.NO_MATCH;
        }
      }
    }
  }
  
  public TuioPoint calcPosBetween (TuioPoint a, TuioPoint b) {
      float aX = a.getX();
      float aY = a.getY();
      return new TuioPoint(aX + ((b.getX()-aX)/2.0), aY + ((b.getY()-aY)/2.0));
  }

  TuioPoint scrollPos;
  int nextStepX = 0;
  int nextStepY = 0;

  public void updateScrollActions() {  
    // Start scrolling size or intensity
    scrollPos = calcPosBetween(cursors.get(0).getPosition(), cursors.get(1).getPosition());
    nextStepX = -round(((scrollPos.getX() - initialPos.getX()) * width) / stepMod);
    nextStepY = round(((scrollPos.getY() - initialPos.getY()) * height) / stepMod);
    float scrollAngle = initialPos.getAngleDegrees(scrollPos);
    float angleThresholdHalf = angleThreshold / 2;
    boolean validAngle = true;
    
    // TODO: Lock one direction
    if (scrollAngle > 360-angleThresholdHalf || scrollAngle < angleThresholdHalf) {mapManager.changeIntensity(nextStepX);}          // Right
    else if (scrollAngle > 90-angleThresholdHalf && scrollAngle < 90+angleThresholdHalf) {mapManager.changeRadius(nextStepY);}      // Up
    else if (scrollAngle > 180-angleThresholdHalf && scrollAngle < 180+angleThresholdHalf) {mapManager.changeIntensity(nextStepX);}  // Left
    else if (scrollAngle > 270-angleThresholdHalf && scrollAngle < 270+angleThresholdHalf) {mapManager.changeRadius(nextStepY);}     // Down
    else {validAngle = false;}
    
    if (validAngle && doDebugOverlay) {
      stroke(color(0,255,0));
      line(initialPos.getScreenX(width), initialPos.getScreenY(height), scrollPos.getScreenX(width), scrollPos.getScreenY(height));
    }
  }
}


public class TouchManager {
  float maxInitialGestureDistance = 0.5f;

  // When cursors are removed, they are
  // Sets of points, that have no matching gesture and are still mutable
  public ArrayList<ArrayList<TuioCursor>> unrecognizedGestures = new ArrayList<ArrayList<TuioCursor>>();
  // Sets of points, that have no matching gesture
  public ArrayList<Gesture> uncertainGestures = new ArrayList<Gesture>();
  public ArrayList<Gesture> activeGestures = new ArrayList<Gesture>();

  public void addCursor(TuioCursor cursor) {
    ArrayList<TuioCursor> newCursorList = new ArrayList<TuioCursor>();
    newCursorList.add(cursor);

    for (Iterator<ArrayList<TuioCursor>> cursorListIterator = unrecognizedGestures.iterator(); cursorListIterator.hasNext(); ) {
      ArrayList<TuioCursor> cursorList = cursorListIterator.next();
      for (TuioCursor oldCursor : cursorList) {
        if (oldCursor.getDistance(cursor) <= maxInitialGestureDistance) {
          cursorListIterator.remove();
          newCursorList.addAll(cursorList);
          for (Iterator<Gesture> iterator = uncertainGestures.iterator(); iterator.hasNext(); ) {
            Gesture gesture = iterator.next();
            if (cursorList.equals(gesture.getCursors())) {
              iterator.remove();
            }
          }
          break;
        }
      }
    }

    unrecognizedGestures.add(newCursorList);

    //TODO add gesture for all supported gestures
    uncertainGestures.add(new ToolGesture(newCursorList));
    uncertainGestures.add(new PinchGesture(newCursorList));
    uncertainGestures.add(new ScrollGesture(newCursorList));
  }

  public void updateCursor(TuioCursor cursor) {
  }
  public void removeCursor(TuioCursor cursor) {
  }
  public void update() {
    //Evaluate gestures
    for (Iterator<Gesture> iterator = uncertainGestures.iterator(); iterator.hasNext(); ) {
      Gesture gesture = iterator.next();
      float certainty = gesture.evaluatePotential();
      if (certainty <= Gesture.NO_MATCH) {
        iterator.remove(); // TODO: ConcurrentModificationException
        boolean last = true;
        for (Gesture otherGesture : uncertainGestures) {
          if (otherGesture.getCursors().equals(gesture.getCursors())) {
            last = false;
            break;
          }
        }
        if (last) {
          unrecognizedGestures.remove(gesture.getCursors());
        }
      }
      if (certainty >= Gesture.MATCH) {
        iterator.remove();
        activeGestures.add(gesture);
        unrecognizedGestures.remove(gesture.getCursors());
      }
    }

    for (Iterator<Gesture> iterator = activeGestures.iterator(); iterator.hasNext(); ) {
      Gesture gesture = iterator.next();
      boolean stillActive = gesture.update();
      if ( !stillActive ) {
        iterator.remove();
      }
    }
  }
}

TouchManager touchManager = new TouchManager();
MapManager mapManager;

boolean verbose = false;
boolean callback = false;

PGraphics mapImage;
Map<String, PImage[]> buttons;

void setup()
{
  //noCursor();
  size(1000, 700);
  noStroke();
  fill(0);

  loop();
  frameRate(60);

  font = createFont("Arial", 12);
  scale_factor = height/table_size;

  tuioClient  = new TuioProcessing(this);
  mapManager = new MapManager();
  mapImage = createGraphics(width, height); //<>//
  loadButtons();
  delay(200);
}

void draw()
{
  mapImage.beginDraw();
  mapImage.noStroke();
  for (int row = 0; row < height; row++) {
    for (int col = 0; col < width; col++) {
      if (changeOccured[row][col]) {
        changeOccured[row][col] = false;
        mapImage.stroke(heightColors[terrainHeight[row][col]]);
        mapImage.point(col, row);  
      }
    }
  }
  mapImage.endDraw();
  image(mapImage, 0, 0); 
  
  String infotext = "";
  
  if (doDebugOverlay) {
    textFont(font, 12*scale_factor);
  
     infotext += touchManager.unrecognizedGestures.size() + " unrecognized gestures\n" +
      touchManager.uncertainGestures.size() + " uncertain gestures\n" +
      touchManager.activeGestures.size() + " active gestures\n";
  
    infotext += "Unrecognized gestures:\n";
  }
  
  touchManager.update();
    
  if (doDebugOverlay) {
    int cursorListCount = 0;
    for (ArrayList<TuioCursor> cursorList : touchManager.unrecognizedGestures) {
      String name = "Unrecognized " + cursorListCount;
      printCursorList(cursorList, name);
  
      cursorListCount++;
      infotext += "    " + name + "\n";
    }
  
    infotext += "Uncertain gestures:\n";
    for (Gesture gesture : touchManager.uncertainGestures) { // TODO: ConcurrentModificationException
      String name = gesture.getClass().getSimpleName();
      printCursorList(gesture.getCursors(), name);
      infotext += "    " + name + "\n";
    }
  
    infotext += "Active gestures:\n";
    for (Gesture gesture : touchManager.activeGestures) {
      String name = gesture.getClass().getSimpleName();
      printCursorList(gesture.getCursors(), name);
      infotext += "    " + name + "\n";
    }
  
      fill(0);
      text( infotext, (5*scale_factor), (15*scale_factor));
  }
}

void printCursorList(ArrayList<TuioCursor> cursorList, String name) {
  for (TuioCursor cursor : cursorList) {
    printCursor(cursor, name);
  }
}
void printCursorList(ArrayList<TuioCursor> cursorList, String name, color col) {
  for (TuioCursor cursor : cursorList) {
    printCursor(cursor, name, col);
  }
}
void printCursor(TuioCursor cursor) {
  printCursor(cursor, "Cursor");
}
void printCursor(TuioCursor cursor, String name) {
  Random generator = new Random(name.hashCode());
  printCursor(cursor, name, color(generator.nextInt(255), generator.nextInt(255), generator.nextInt(255)));
}
void printCursor(TuioCursor cursor, String name, color col) {
  printCursor(cursor, name, col, (int)cursor.getSessionID());
}
void printCursor(TuioCursor cursor, String name, color col, int number) {
  ArrayList<TuioPoint> pointList = cursor.getPath();
  float cur_size = cursor_size*scale_factor; 

  if (pointList.size()>0) {
    stroke(lerpColor(col, 0, 0.5));
    TuioPoint start_point = pointList.get(0);
    for (int j=0; j<pointList.size(); j++) {
      TuioPoint end_point = pointList.get(j);
      line(start_point.getScreenX(width), start_point.getScreenY(height), end_point.getScreenX(width), end_point.getScreenY(height));
      start_point = end_point;
    }

    stroke(lerpColor(col, 0, 0.5));
    fill(col);
    ellipse( cursor.getScreenX(width), cursor.getScreenY(height), cur_size, cur_size);
    stroke(#FFFFFF);
    fill(0);
    text(""+ number, cursor.getScreenX(width)-(5*scale_factor), cursor.getScreenY(height)+(5*scale_factor));
    text(name, cursor.getScreenX(width)+(5*scale_factor), cursor.getScreenY(height)-(5*scale_factor));
  }
}

void addTuioCursor(TuioCursor tcur) {
  if (verbose) println("add cur "+tcur.getCursorID()+" ("+tcur.getSessionID()+ ") " +tcur.getX()+" "+tcur.getY());
  touchManager.addCursor(tcur);
}

// called when a cursor is moved
void updateTuioCursor (TuioCursor tcur) {
  if (verbose) println("set cur "+tcur.getCursorID()+" ("+tcur.getSessionID()+ ") " +tcur.getX()+" "+tcur.getY()
    +" "+tcur.getMotionSpeed()+" "+tcur.getMotionAccel());
  touchManager.updateCursor(tcur);
}

void removeTuioCursor(TuioCursor tcur) {
  if (verbose) println("del cur "+tcur.getCursorID()+" ("+tcur.getSessionID()+")");
  touchManager.removeCursor(tcur);
}


// Unused dummy functions.
void addTuioBlob(TuioBlob tblb) {
  if (verbose) println("add blb "+tblb.getBlobID()+" ("+tblb.getSessionID()+") "+tblb.getX()+" "+tblb.getY()+" "+tblb.getAngle()+" "+tblb.getWidth()+" "+tblb.getHeight()+" "+tblb.getArea());
}
void updateTuioBlob (TuioBlob tblb) {
  if (verbose) println("set blb "+tblb.getBlobID()+" ("+tblb.getSessionID()+") "+tblb.getX()+" "+tblb.getY()+" "+tblb.getAngle()+" "+tblb.getWidth()+" "+tblb.getHeight()+" "+tblb.getArea()
    +" "+tblb.getMotionSpeed()+" "+tblb.getRotationSpeed()+" "+tblb.getMotionAccel()+" "+tblb.getRotationAccel());
}
void removeTuioBlob(TuioBlob tblb) {
  if (verbose) println("del blb "+tblb.getBlobID()+" ("+tblb.getSessionID()+")");
}
void addTuioObject(TuioObject tobj) {
  if (verbose) println("add obj "+tobj.getSymbolID()+" ("+tobj.getSessionID()+") "+tobj.getX()+" "+tobj.getY()+" "+tobj.getAngle());
}
void updateTuioObject (TuioObject tobj) {
  if (verbose) println("set obj "+tobj.getSymbolID()+" ("+tobj.getSessionID()+") "+tobj.getX()+" "+tobj.getY()+" "+tobj.getAngle()
    +" "+tobj.getMotionSpeed()+" "+tobj.getRotationSpeed()+" "+tobj.getMotionAccel()+" "+tobj.getRotationAccel());
}
void removeTuioObject(TuioObject tobj) {
  if (verbose) println("del obj "+tobj.getSymbolID()+" ("+tobj.getSessionID()+")");
}
void refresh(TuioTime frameTime) {
  if (verbose) println("frame #"+frameTime.getFrameID()+" ("+frameTime.getTotalMilliseconds()+")");
}

void loadButtons() {
  buttons = new HashMap<String, PImage[]>();
   
  PImage[] buttonArray = new PImage[3];
  buttonArray[0] = loadImage("Buttons_Raise_1.png");
  buttonArray[1] = loadImage("Buttons_Raise_2.png");
  buttonArray[2] = loadImage("Buttons_Raise_3.png");
  buttons.put("Raise", buttonArray.clone());
  
  buttonArray[0] = loadImage("Buttons_Lower_1.png");
  buttonArray[1] = loadImage("Buttons_Lower_2.png");
  buttonArray[2] = loadImage("Buttons_Lower_3.png");
  buttons.put("Lower", buttonArray.clone());
  
  buttonArray[0] = loadImage("Buttons_Smooth_1.png");
  buttonArray[1] = loadImage("Buttons_Smooth_2.png");
  buttonArray[2] = loadImage("Buttons_Smooth_3.png");
  buttons.put("Smooth", buttonArray.clone());
}


enum Tool {
  RAISE_TERRAIN,
  LOWER_TERRAIN,
  BLUR_TERRAIN
}

  int[][] terrainHeight;
  boolean[][] changeOccured;
  
  final color[] heightColors = new color[501];
  final color lineColor = color(30,30,30);

class MapManager {
  int brushRadius = 50;
  int brushIntensity = 10;
  ArrayList<int[]> brushPixels = new ArrayList<int[]>();
  
  Tool tool = Tool.RAISE_TERRAIN;
    
  MapManager() {  
    initTerrainHeight();
    initHeightColors();
    calcBrush(brushRadius);
  }
  
  void useTool(TuioPoint toolPosition) {
    int toolX = round(toolPosition.getX()*width); 
    int toolY = round(toolPosition.getY()*height); 
    if (tool == Tool.BLUR_TERRAIN) {
      int[][] terrainHeightCopy = terrainHeight;
      
      int smoothingIntensity = brushIntensity / 4;
      
      for (int[] pixel : brushPixels) {
        int col = pixel[0] + toolX;
        int row = pixel[1] + toolY;

        if (col > 0 && row > 0 && col < width && row < height) {
          float avg = 0;
          float smoothingDivider = 0;
          
          for (int i = -smoothingIntensity; i <= smoothingIntensity; i++) {
            for (int j = -smoothingIntensity; j <= smoothingIntensity; j++) {
              int coli = col + i;
              int rowj = row + j;
              if (coli > 0 && rowj > 0 && coli < width && rowj < height) {
                float weight = (float(smoothingIntensity - abs(i)) / float(smoothingIntensity * 2)) + (float(smoothingIntensity - abs(j)) / float(smoothingIntensity * 2));
                avg += terrainHeight[rowj][coli] * weight;
                smoothingDivider += weight;
              }
            }
          }
          avg = avg / smoothingDivider;
          terrainHeightCopy[row][col] = round(avg);
        }
      }
      
      for (int[] pixel : brushPixels) {
        int col = pixel[0] + toolX;
        int row = pixel[1] + toolY;
        if (col > 0 && row > 0 && col < width && row < height) {
          changePoint(col, row, terrainHeightCopy[row][col]);
        }
      }
            
    } else {
      for (int[] pixel : brushPixels) {
        int col = pixel[0] + toolX;
        int row = pixel[1] + toolY;
        if (col > 0 && row > 0 && col < width && row < height) {
          if (tool == Tool.RAISE_TERRAIN) {
              changePoint(col, row, constrain(terrainHeight[row][col] + brushIntensity, 0, 500));
          } else if (tool == Tool.LOWER_TERRAIN) {
              changePoint(col, row, constrain(terrainHeight[row][col] - brushIntensity, 0, 500));
          }
        } 
      }
    }
  }
  
  void changeTool (Tool newTool) {
      tool = newTool;
  }
  
  void changeRadius (int change) {
    brushRadius -= change;
    brushRadius = constrain(brushRadius,1,100);
    calcBrush (brushRadius);
    if (doDebugOverlay) {
      textFont(font, 12*scale_factor);
      fill(0);  
      text("Radius: " + brushRadius, 0, height-20);
    }
    println("Radius: " + brushRadius);
  }
  
  void changeIntensity (int change) {
    brushIntensity -= change;
    brushIntensity = constrain(brushIntensity,4,100);
    if (doDebugOverlay) {
      textFont(font, 12*scale_factor);
      fill(0);
      text("Intensity: " + brushIntensity, 0, height-40);
    }
    println("Intensity: " + brushIntensity);
  }
  
  
  void calcBrush (int radius) {
    brushPixels.clear();
    int radiusSquared = radius * radius;
    
    for (int row = -brushRadius; row < brushRadius; row++) {
      for (int col = -brushRadius; col < brushRadius; col++) {
        float distanceSquared = (row) * (row) + (col) * (col);
        if (distanceSquared <= radiusSquared) {
          int[] pixel = {col,row};
          brushPixels.add(pixel);
        }
      } 
    } 
  }
  
  void changePoint (int col, int row, int newValue) {
    terrainHeight[row][col] = newValue;
    changeOccured[row][col] = true; 
  }
  
  void initTerrainHeight() {
    terrainHeight = new int[height][width];
    changeOccured = new boolean[height][width];
    
    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        // TODO: some more interesting initialization with noise or something
        terrainHeight[row][col] = 0;
        changeOccured[row][col] = true;
      }
    }
  }
  
  void initHeightColors() {
    heightColors[0] = color(50, 120, 200);
    heightColors[100] = color(150, 200, 255);
    heightColors[200] = color(150, 190, 140);
    heightColors[300] = color(240, 240, 190);
    heightColors[400] = color(170, 135, 80);
    heightColors[500] = color(230, 230, 220);
    
    // TODO: How would a color gradient be better programmed?
    for (int i = 0; i < 100; i++) {
      heightColors[i] = lerpColor(heightColors[0], heightColors[100], float(i)/100);
    }
    
    for (int i = 100; i < 200; i++) {
      heightColors[i] = lerpColor(heightColors[100], heightColors[200], float(i-100)/100);
    }
    
    for (int i = 200; i < 300; i++) {
      heightColors[i] = lerpColor(heightColors[200], heightColors[300], float(i-200)/100);
    }
    
    for (int i = 300; i < 400; i++) {
      heightColors[i] = lerpColor(heightColors[300], heightColors[400], float(i-300)/100);
    }
    
    for (int i = 400; i < 500; i++) {
      heightColors[i] = lerpColor(heightColors[400], heightColors[500], float(i-400)/100);
    }
  }
}
