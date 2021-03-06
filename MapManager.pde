class MapManager {
  // The maximum height that can be stored in terrainHeight
  static final int max_height = 65535;
  // The maximum size of the brush. (mm)
  static final int max_brush_size = 80;
  // The minimum size of the brush. (mm)
  static final int min_brush_size = 10;
  // The initial size of the brush. (mm)
  static final int initial_brush_size = 40;
  // The minimum intensity of the brush. (multiplier)
  static final float min_brush_intensity = 0.1;
  // The maximum intensity of the brush. (multiplier)
  static final float max_brush_intensity = 1.0;
  // A multiplier for the intensity
  static final int raise_factor = 64;
  // Relevant for the legend markings
  // The height of the lowest possible point in meters
  static final int lowest_elevation = -4250;
  // The height of the highest possible point in meters
  static final int elevation_range = 8500;
  // Number of different colors on the map
  int steps = 34;
  // Legend dimensions
  static final int legend_width = 160;
  static final int legend_field_height = 15;
  static final int legend_side_margin = 10;
  static final int legend_top_margin = 10;
  static final float legend_text_width = 0.40;
  static final int legend_screen_bottom_distance = 20;
  static final int legend_screen_side_distance = 30;

  float[][] brush;
  Tool tool = Tool.RAISE_TERRAIN;
  PShader mapShader;
  PImage colorTexture;
  PImage legendImage;
  float brushSize;
  float brushIntensity = 1.0;
  PImage terrainHeight;

  MapManager() {
    initializeMapImage();
    initTerrainHeight();
    prepareMapShader();
    prepareLegendKeyImage();
    prepareBrush();
  }

  void initializeMapImage() {
    terrainHeight = createImage(width, height, RGB);
    terrainHeight.loadPixels();
  }

  // Get the brush value at the given coordinates of the brush.
  // The input values are between 0 and brushSize
  float brushAt(int x, int y) {
    int toolSizeX = brush.length;
    int toolSizeY = brush[0].length;
    float scalingFactorX = float(toolSizeX - 1) / brushSize;
    float scalingFactorY = float(toolSizeY - 1) / brushSize;
    float positionX = scalingFactorX * x;
    float positionY = scalingFactorY * y;
    int lowerX = constrain(int(positionX), 0, toolSizeX - 1);
    int lowerY = constrain(int(positionY), 0, toolSizeY - 1);
    float lowerValue = lerp(brush[lowerX][lowerY], brush[lowerX + 1][lowerY], positionX - int(positionX));
    float upperValue = lerp(brush[lowerX][lowerY + 1], brush[lowerX + 1][lowerY + 1], positionX - int(positionX));
    float realValue = lerp(lowerValue, upperValue, positionY - int(positionY));
    return realValue * brushIntensity;
  }

  void useTool(TuioPoint toolPosition) {
    int toolX = round(toolPosition.getX() * width);
    int toolY = round(toolPosition.getY() * height);

    for (int x = 0; x < int(brushSize); x++) {
      for (int y = 0; y < int(brushSize); y++) {
        float intensity = brushAt(x, y);
        int mapX = x + toolX - (int) (brushSize / 2);
        int mapY = y + toolY - (int) (brushSize / 2);

        if (mapX > 0 && mapY > 0 && mapX < width && mapY < height) {
          switch (tool) {
            case RAISE_TERRAIN:
              terrainHeight.pixels[mapX + (mapY * width)] = constrain(terrainHeight.pixels[mapX + (mapY * width)] + int(intensity * raise_factor), 0, max_height);
              break;

            case LOWER_TERRAIN:
              terrainHeight.pixels[mapX + (mapY * width)] = constrain(terrainHeight.pixels[mapX + (mapY * width)] - int(intensity * raise_factor), 0, max_height);
              break;

            case SMOOTH_TERRAIN:
              float avg = 0;
              float smoothingDivider = 0;
              int smoothingIntensity = 2;
              for (int i = -smoothingIntensity; i <= smoothingIntensity; i++) {
                for (int j = -smoothingIntensity; j <= smoothingIntensity; j++) {
                  int smoothX = mapX + i;
                  int smoothY = mapY + j;

                  if (smoothX > 0 && smoothY > 0 && smoothX < width && smoothY < height) {
                    float weight = (float(smoothingIntensity - abs(i)) / float(smoothingIntensity * 2)) + (float(smoothingIntensity - abs(j)) / float(smoothingIntensity * 2));
                    avg += terrainHeight.pixels[smoothX + (smoothY * width)] * weight;
                    smoothingDivider += weight;
                  }
                }
              }
              avg = avg / smoothingDivider;
              terrainHeight.pixels[mapX + (mapY * width)] = round(avg);
              break;

            case SPECIAL:
              return;
          }
        }
      }
    }
  }

  void setTool(Tool newTool) {
    tool = newTool;
  }

  Tool getTool() {
    return tool;
  }

  // Adjust brush size in mm
  void changeBrushSize(float size) {
    float minSizePixels = min_brush_size / screen_pixel_width;
    float maxSizePixels = max_brush_size / screen_pixel_width;
    brushSize = constrain(brushSize + (size / screen_pixel_width), minSizePixels, maxSizePixels);
  }

  // Return the brush diameter in mm
  float getBrushSize() {
    return brushSize * screen_pixel_width;
  }

  void changeBrushIntensity(float intensity) {
    brushIntensity = constrain(brushIntensity + intensity, min_brush_intensity, max_brush_intensity);
  }

  float getBrushIntensity() {
    return brushIntensity;
  }

  void prepareBrush() {
    int round_brush_size = 20;
    float[][] roundBrush = new float[round_brush_size][round_brush_size];
    for (int x = 0; x < round_brush_size; x++) {
      for (int y = 0; y < round_brush_size; y++) {
        float adjustedX = (x * 2 / float(round_brush_size - 1)) - 1;
        float adjustedY = (y * 2 / float(round_brush_size - 1)) - 1;
        float value = -(adjustedX * adjustedX) - (adjustedY * adjustedY) + 1;
        roundBrush[x][y] = constrain(value, 0, 1.0);
      }
    }

    brush = roundBrush;

    brushSize = initial_brush_size / screen_pixel_width;
  }

  color getStepColor(int step) {
    if (step < 0 || step > steps - 1) {
      return color(0);
    }
    int pos = int((float(step) / float(steps)) * 255f);
    return colorTexture.pixels[pos];
  }

  int getStepElevation(int step) {
    if (step < 0 || step > steps) {
      return 0;
    }
    return lowest_elevation + int(step * (float(elevation_range) / steps));
  }

  void drawLegendField(PGraphics g, int step, int width, int height) {
    g.stroke(color(0));
    g.fill(getStepColor(step));
    g.rect(0, 0, width, height);
  }

  void drawLegendMeterMarking(PGraphics g, int step) {
    g.fill(color(0));
    g.textAlign(LEFT, CENTER);
    g.text(getStepElevation(step) + "m", 0, 0);
  }

  void prepareLegendKeyImage() {
    int legendHeight = legend_top_margin * 2 + (steps + 1) * legend_field_height;
    PGraphics g = createGraphics(legend_width, legendHeight);
    g.beginDraw();

    // Some name values
    int fieldHeight = legend_field_height;
    int textWidth = int((legend_width - (legend_side_margin * 2)) * legend_text_width);
    int fieldWidth = (legend_width - (legend_side_margin * 2)) - textWidth;

    // Draw background
    g.noStroke();
    g.fill(color(255, 255, 255, 150));
    g.rect(0, 0, legend_width, legendHeight, 9, 9, 9, 9);

    // Prepare for contents
    g.pushMatrix();
    g.translate(legend_side_margin, legend_top_margin + (fieldHeight / 2));

    // Draw colored fields
    g.pushMatrix();
    g.translate(textWidth, 0);
    for (int step = steps - 1; step >= 0; step--) {
      drawLegendField(g, step, fieldWidth, fieldHeight);
      g.translate(0, fieldHeight);
    }
    g.popMatrix();

    // Draw meter markings
    g.pushMatrix();
    g.translate(0, 0);
    for (int step = steps; step >= 0; step--) {
      drawLegendMeterMarking(g, step);
      g.translate(0, fieldHeight);
    }
    g.popMatrix();

    g.endDraw();
    legendImage = g.get(0, 0, legend_width, legendHeight);
  }

  void initTerrainHeight() {
    noiseSeed(System.currentTimeMillis());
    float noiseStep = 0.008; // FROM max ~0.03 Small detailled 'rocks'

    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        int noiseFeatureHeight = round(noise(noiseStep * col, noiseStep * row) * max_height);
        terrainHeight.pixels[col + (row * width)] = noiseFeatureHeight;
      }
    }
  }

  void drawMap() {
    if(terrainHeight.width != width || terrainHeight.height != height){
      initializeMapImage();
      initTerrainHeight();
    }
    terrainHeight.updatePixels();
    pushMatrix();
    shader(mapShader);
    image(terrainHeight, 0, 0);
    resetShader();
    popMatrix();
    image(legendImage, width - legendImage.width - legend_screen_side_distance, height - legendImage.height - legend_screen_bottom_distance);
  }

  PImage generateColorTexture(color[] colors, float[] positions) throws Exception {
    if (colors.length != positions.length) {
      throw new Exception("NOPE");
    }

    // Has to start with 0
    if (positions[0] != 0.0) {
      throw new Exception("NOPE");
    }

    // Has to end with 1
    if (positions[positions.length - 1] != 1.0) {
      throw new Exception("NOPE");
    }

    // Positions need to increase
    for (int testPos = 1; testPos < positions.length; testPos++) {
      if (positions[testPos] < positions[testPos - 1]) {
        throw new Exception("NOPE");
      }
    }

    PGraphics g = createGraphics(255, 1);
    g.beginDraw();

    for (int step = 1; step < positions.length; step++) {
      for (int pos = int(positions[step - 1] * 255f); pos < positions[step] * 255; pos++) {
        g.noStroke();
        g.fill(lerpColor(colors[step - 1], colors[step], float(pos - int(positions[step - 1] * 255f)) / float(int(positions[step] * 255f) - int(positions[step - 1] * 255f))));
        // Point does for some reason not paint the color accuratly, so rect is used
        g.rect(pos, 0, 1, 1);
      }
    }
    g.endDraw();
    return g.get(0, 0, 255, 1);
  }

  void prepareMapShader() {
    int steps = 34;

    color[] colors = new color[7];
    colors[0] = color(99, 159, 211);
    colors[1] = color(227, 244, 254);
    colors[2] = color(164, 217, 154);
    colors[3] = color(129, 192, 116);
    colors[4] = color(243, 240, 194);
    colors[5] = color(194, 140, 33);
    colors[6] = color(175, 91, 0);

    float[] positions = new float[7];
    positions[0] = 0f;
    positions[1] = float((steps / 2) - 1) / steps;
    positions[2] = 0.5f;
    positions[3] = float((steps / 2) + 1) / steps;
    positions[4] = 0.67f;
    positions[5] = 0.9f;
    positions[6] = 1f;

    try {
      colorTexture = generateColorTexture(colors, positions);
    } catch (Exception e) {
      println("EXCEPTION: " + e);
      return;
    }

    mapShader = loadShader("res/mapshader.glsl");
    mapShader.set("steps", steps);
    mapShader.set("shadingIntensity", 2);
    mapShader.set("lineIntensity", 0.7f);
    mapShader.set("colorTexture", colorTexture);
  }
}
