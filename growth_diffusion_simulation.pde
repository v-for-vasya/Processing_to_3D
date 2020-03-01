import processing.svg.*;
import processing.pdf.*;
import processing.dxf.*;
import nervoussystem.obj.*; // Download at https://n-e-r-v-o-u-s.com/tools/obj/

// Press 'E' to export as .obj when you like the shape and press 'R' to refresh the simulation. 

// PARAMETERS
float _maxForce = 1.00; // play around with parameter values
float _maxForceNoise = 2.75;
float _maxSpeed = 1.4; 
float _desiredSeparation = 8; 
float _separationCohesionRation = 1;
float _maxEdgeLen = 5; 

int savedTime;
int totalTime = 1000; // time interval in milliseconds 1000 = 1 second

color background_color = #111111;
color stroke_color = #ffffff;
color fill_color = color(225, 225, 225);
long _randomSeed;

DifferentialLine _diff_line;  

void setup() {
  size(1280,720, P3D ); //resolution size
  startNewLine();
  savedTime = millis();
}

void draw() {
  background(background_color);
  _diff_line.run();
  _diff_line.renderAsLine();
  int passedTime = millis() - savedTime;
  if (passedTime > totalTime) { 
    /*if you want to save an .obj file every 1000 milliseconds to capture the growth process and reconstruct it in 3D software
    _diff_line.exportOBJ();
    */
    savedTime = millis();
  }
  //displayFrameRate();
  //_diff_line.exportMovieFrame(); 
}

class DifferentialLine {
  ArrayList<Node> nodes;
  float maxForce;
  float maxForceNoise;
  float maxSpeed;
  float desiredSeparation;
  float sq_desiredSeparation;
  float separationCohesionRation;
  float maxEdgeLen;

  DifferentialLine(float mF, float mFn, float mS, float dS, float sCr, float eL) {
    nodes = new ArrayList<Node>();
    maxForce = mF;
    maxForceNoise = mFn;
    maxSpeed = mS;
    desiredSeparation = dS;
    sq_desiredSeparation = sq(desiredSeparation);
    separationCohesionRation = sCr;
    maxEdgeLen = eL;
  }

  void addNode(Node n) {
    nodes.add(n);
  }

  void addNodeAt(Node n, int index) {
    nodes.add(index, n);
  }

  void run() {
    differentiate();
    growth();
  }

  void blindRun(int iterations) { // For exporting without rendering
    for (int i=0; i<iterations; i++) {
      float progress = (i / (float)iterations) * 100;
      if (progress%5 == 0) {
        println(progress + "%...");
      }
      run();
    }
    println("Done.\n\n");
  }

  void growth() {
    for (int i=0; i<nodes.size()-1; i++) {
      Node n1 = nodes.get(i);
      Node n2 = nodes.get(i+1);
      float d = PVector.dist(n1.position, n2.position);
      if (d>maxEdgeLen) { // Can add more rules for inserting nodes
        int index = nodes.indexOf(n2);
        PVector middleNode = PVector.add(n1.position, n2.position).div(2);
        addNodeAt(new Node(middleNode.x, middleNode.y, maxForce, maxSpeed), index);
      }
    }
  }


  void checkBorders(Node n, float border) {
    if (n.position.x < border || n.position.x >width - border)
      n.velocity.x*=-1;
    if (n.position.y < border || n.position.y > height - border)
      n.velocity.y*=-1;
  }

   

  PVector[] getSeparationForces() {
    int n = nodes.size();
    PVector[] separateForces=new PVector[n];
    int[] nearNodes = new int[n];
    Node nodei;
    Node nodej;
    for (int i=0; i<n; i++) {
      separateForces[i]=new PVector();
    }
    for (int i=0; i<n; i++) {
      nodei=nodes.get(i);
      for (int j=i+1; j<n; j++) {
        nodej=nodes.get(j);
        PVector forceij = getSeparationForce(nodei, nodej);
        if (forceij.mag()>0) {
          separateForces[i].add(forceij);        
          separateForces[j].sub(forceij);
          nearNodes[i]++;
          nearNodes[j]++;
        }
      }
      if (nearNodes[i]>0) {
        separateForces[i].div((float)nearNodes[i]);
      }
      if (separateForces[i].mag() >0) {
        separateForces[i].setMag(maxSpeed);
        separateForces[i].sub(nodes.get(i).velocity);
        separateForces[i].limit(maxForce);
      }
    }
    return separateForces;
  }
  PVector getSeparationForce(Node n1, Node n2) {
    PVector steer = new PVector(0, 0);
    float sq_d = sq(n2.position.x-n1.position.x)+sq(n2.position.y-n1.position.y);
    if (sq_d>0 && sq_d<sq_desiredSeparation) {
      PVector diff = PVector.sub(n1.position, n2.position);
      diff.normalize();
      diff.div(sqrt(sq_d)); //Weight by distacne
      steer.add(diff);
    }
    return steer;
  }
  PVector[] getEdgeCohesionForces() {
    int n = nodes.size();
    PVector[] cohesionForces=new PVector[n];
    for (int i=0; i<nodes.size(); i++) {
      PVector sum = new PVector(0, 0);      
      if (i!=0 && i!=nodes.size()-1) {
        sum.add(nodes.get(i-1).position).add(nodes.get(i+1).position);
      } else if (i == 0) {
        sum.add(nodes.get(nodes.size()-1).position).add(nodes.get(i+1).position);
      } else if (i == nodes.size()-1) {
        sum.add(nodes.get(i-1).position).add(nodes.get(0).position);
      }
      sum.div(2);
      cohesionForces[i] = nodes.get(i).seek(sum);
    }
    return cohesionForces;
  }
  
   void differentiate() {
      updateMaxForceByPosition();
      PVector[] separationForces = getSeparationForces();
      PVector[] cohesionForces = getEdgeCohesionForces();
      for (int i=0; i<nodes.size(); i++) {
        PVector separation = separationForces[i];
        PVector cohesion = cohesionForces[i];
        separation.mult(separationCohesionRation);
        nodes.get(i).applyForce(separation);
        nodes.get(i).applyForce(cohesion);
        nodes.get(i).update();
      }
    }
    void updateMaxForceByPosition() {
      if (!Float.isNaN(maxForceNoise)) {
        for (int i=0; i<nodes.size(); i++) {
          float new_max_force = noise(nodes.get(i).position.x/10, nodes.get(i).position.y/10) * maxForceNoise;
          nodes.get(i).maxForce = new_max_force;
        }
      }
    }

  void renderAsShape() {
    stroke(stroke_color);
    fill(fill_color);
    beginShape();
    for (int i=0; i<nodes.size(); i++) {
      vertex(nodes.get(i).position.x, nodes.get(i).position.y);
    }
    endShape(CLOSE);
  }

  void renderAsLine() {
    stroke(stroke_color);
    for (int i=0; i<nodes.size()-1; i++) {
      PVector p1 = nodes.get(i).position;
      PVector p2 = nodes.get(i+1).position;
      line(p1.x, p1.y, p2.x, p2.y);
      if (i==nodes.size()-2) {
        line(p2.x, p2.y, nodes.get(0).position.x, nodes.get(0).position.y);
      }
    }
  }

  void exportPNG() {
    String exportName = getSaveName()+".png";
    saveFrame(exportName);

    println(exportName + " saved.");
  }

  void exportPNG(String name) {
    String exportName = name+".png";
    saveFrame(name + ".png");

    println(exportName + " saved.");
  }

  void exportMovieFrame() {
    saveFrame("frames/#####.tga");
  }

  void exportDXF() {
    String exportName = getSaveName()+".dxf";
    PGraphics pg = createGraphics(width, height, DXF, exportName);
    pg.beginDraw();
    for (int i=0; i<nodes.size()-1; i++) {
      PVector p1 = nodes.get(i).position;
      PVector p2 = nodes.get(i+1).position;
      pg.line(p1.x, p1.y, p2.x, p2.y);
      if (i==nodes.size()-2) {
        pg.line(p2.x, p2.y, nodes.get(0).position.x, nodes.get(0).position.y);
      }
    }
    pg.endDraw();
    pg.dispose();
    pg.endRaw();

    println(exportName + " saved.");
  }

  void exportOBJ() {
    String export_name = day()+""+hour()+""+minute()+""+second();
    OBJExport obj = (OBJExport) createGraphics(1280, 720, "nervoussystem.obj.OBJExport", export_name+".obj");
    obj.beginDraw();
    obj.beginShape();
    for (int i=0; i<nodes.size(); i++) {
      PVector p1 = nodes.get(i).position;
      obj.vertex(p1.x, p1.y);
    }
    obj.endShape();
    obj.endDraw();
    obj.dispose();
    renderAsLine();
    println(export_name + ".obj saved.");
  }

  void exportSVG() {
    String exportName = getSaveName()+".svg";
    PGraphics pg = createGraphics(width, height, SVG, exportName);
    pg.beginDraw();
    pg.beginShape();
    for (int i=0; i<nodes.size(); i++) {
      pg.vertex(nodes.get(i).position.x, nodes.get(i).position.y);
    }
    pg.endShape(CLOSE);
    pg.endDraw();
    pg.dispose();

    println(exportName + " saved.");
  }

  void exportPDF() {
    String exportName = getSaveName()+".pdf";
    PGraphics pg = createGraphics(width, height, PDF, exportName);
    pg.beginDraw();
    pg.beginShape();
    for (int i=0; i<nodes.size(); i++) {
      pg.vertex(nodes.get(i).position.x, nodes.get(i).position.y);
    }
    pg.endShape(CLOSE);
    pg.dispose();
    pg.endDraw();

    println(exportName + " saved.");
  }


  String getSaveName() {
    return  day()+""+hour()+""+minute()+""+second();
  }
}


class Node {
  PVector position;
  PVector velocity;
  PVector acceleration;

  float maxForce;
  float maxSpeed;

  Node(float x, float y, float mF, float mS) {
    acceleration = new PVector(0, 0);
    velocity =PVector.random2D();
    position = new PVector(x, y);
    maxSpeed = mF;
    maxForce = mS;
  }

  void applyForce(PVector force) {
    acceleration.add(force);
  }

  void update() {
    velocity.add(acceleration);
    velocity.limit(maxSpeed);
    position.add(velocity);
    acceleration.mult(0);
  }

  PVector seek(PVector target) {
    PVector desired = PVector.sub(target, position);
    desired.setMag(maxSpeed);
    PVector steer = PVector.sub(desired, velocity);
    steer.limit(maxForce);
    return steer;
  }

  void render() {
    fill(0);
    ellipse(position.x, position.y, 2, 2);
  }
}

void startNewLine() {
  _randomSeed = (long)random(-1000000, 1000000);
  println("Random seed: " + _randomSeed);
  randomSeed(_randomSeed);

  _diff_line = new DifferentialLine(_maxForce, _maxForceNoise, _maxSpeed, _desiredSeparation, _separationCohesionRation, _maxEdgeLen);

  float nodesStart = 20;
  float angInc = TWO_PI/nodesStart;
  float rayStart = 10;

  for (float a=0; a<TWO_PI; a+=angInc) {
    float x = width/2 + cos(a) * rayStart;
    float y = height/2 + sin(a) * rayStart;
    _diff_line.addNode(new Node(x, y, _diff_line.maxForce, _diff_line.maxSpeed));
  }
}

void displayFrameRate() {
  fill(255);
  text((int)_randomSeed, 20, 20);
  text((int)frameRate, 20, 35);
}


void keyPressed() {
  if (key == 's' || key == 'S') {
    //_diff_line.exportPNG();
  } else if (key == 'e' || key == 'E') {
    //_diff_line.exportPDF();
    //_diff_line.exportDXF();
    _diff_line.exportOBJ();
    //_diff_line.exportSVG();
  } else if (key == 'r' || key == 'R') { 
    startNewLine();
  }
}
