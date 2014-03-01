// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:async';
import 'dart:math';

// Device access.
import 'package:rikulo_gap/device.dart';
import 'package:rikulo_gap/accelerometer.dart';
import 'package:rikulo_gap/barometer.dart';
import 'package:rikulo_gap/geolocation.dart';
import 'package:rikulo_gap/gyroscope.dart';

// Charts.
import 'package:chart/chart.dart';

// Vector math.
import 'package:vector_math/vector_math.dart';

double abs(double x) => x < 0.0 ? -x : x;


// From http://en.wikipedia.org/wiki/Barometric_formula
double altitude(double pressure_hPa) {
  double p0 = 101325.00;  // Static pressure (pascals).
  double t0 = 288.15;  // Standard temperature (K) [15C].
  double l0 = -0.0065;  // Standard temperature lapse rate (K/m).
  double h0 = 0.0;  // Height at bottom of layer b (m).
  double r = 8.31432;  //  Universal gas constant for air (N*m/mol*K).
  double g = 9.80665;  // Gravitational acceleration (m/s^2).
  double m = 0.0289644;  // Molar mass of Earth's air (kg/mol).
  double p = pressure_hPa * 100.0;

  return ((t0 / (pow(p/p0, (r*l0)/(g*m))) - t0)/l0) + h0;
}

Vecotr3 up = new Vector3.zero();
int ts = 0;

// If the magnitude of the acceleration vector is ~g, then we can figure
// out which way is up.
void updateUpWithAcceleration(Acceleration accel) {
  double mag = sqrt(accel.x*accel.x + accel.y*accel.y + accel.z*accel.z);
  if ((mag > 9.5) && (mag < 10.5)) {
    up.setValues(accel.x/mag, accel.y/mag, accel.z/mag);
  }
}


void updateUpWithAngularSpeed(AngularSpeed speed) {
  speed.doRotation(up, ts);
}


double simpleAngle() {
  double sign = (up.x >= 0.0) ? -1.0 : 1.0;
  double up_dot_y = up.y;
  double mag = sqrt(up.x*up.x + up.y*up.y);
  return sign * acos(up_dot_y / mag);
}


String showAcceleration(Line chart, CanvasRenderingContext2D context,
                        List<double> xdata,
                        List<double> ydata,
                        List<double> zdata,
                        List<double> mdata) {
  querySelector("#accel_id").text = "Acceleration: Looking";
  querySelector("#accel_x_id").text = "x: ???";
  querySelector("#accel_y_id").text = "y: ???";
  querySelector("#accel_z_id").text = "z: ???";
  querySelector("#accel_mag_id").text = "mag: ???";
  var id = accelerometer.watchAcceleration(
    (accel) {
      double mag = sqrt(accel.x*accel.x + accel.y*accel.y + accel.z*accel.z);
      String x = accel.x.toStringAsFixed(2);
      String y = accel.y.toStringAsFixed(2);
      String z = accel.z.toStringAsFixed(2);
      String m = mag.toStringAsFixed(2);
      querySelector("#accel_id").text = "Acceleration:";
      querySelector("#accel_x_id").text = "x: $x";
      querySelector("#accel_y_id").text = "y: $y";
      querySelector("#accel_z_id").text = "z: $z";
      querySelector("#accel_mag_id").text = "total: $m";
      xdata.removeLast();
      ydata.removeLast();
      zdata.removeLast();
      mdata.removeLast();
      xdata.insert(0, abs(accel.x));
      ydata.insert(0, abs(accel.y));
      zdata.insert(0, abs(accel.z));
      mdata.insert(0, mag);
      chart.show(querySelector('#accel_chart_id'));
      updateUpWithAcceleration(accel);
    },
    () {
      querySelector("#accel_id").text = "Accelerometer Fail";
    },
    new AccelerometerOptions(frequency:500)
  );
  return id;
}


String showPressure(Line chart, List<double> bdata) {
  querySelector("#pressure_id").text = "Pressure: Looking";
  querySelector("#pressure_hPa_id").text = "??? hPa";
  querySelector("#altitude_id").text = "Altitude: Looking";
  querySelector("#altitude_m_id").text = "??? m";
  var id = barometer.watchPressure(
    (pressure) {
      double alt = altitude(pressure.val);
      String p = pressure.val.toStringAsFixed(2);
      String a = alt.toStringAsFixed(2);
      querySelector("#pressure_id").text = "Pressure:";
      querySelector("#pressure_hPa_id").text = "${p} hPa";
      querySelector("#altitude_id").text = "Altitude:";
      querySelector("#altitude_m_id").text = "${a} m";
      bdata.removeLast();
      bdata.insert(0, alt);
      chart.show(querySelector('#baro_chart_id'));
    },
    () {
      querySelector("#pressure_id").text = "Pressure: Fail";
      querySelector("#altitude_id").text = "Altitude: Fail";
    },
    new BarometerOptions(frequency:500)
  );
  return id;
}


String showLocation() {
  querySelector("#location_id").text = "Location: Looking";
  querySelector("#location_lat_id").text = "lat: ???";
  querySelector("#location_lon_id").text = "lon: ???";
  var id = geolocation.watchPosition(
    (pos) {
      String lat = pos.coords.latitude.toStringAsFixed(2);
      String lon = pos.coords.longitude.toStringAsFixed(2);
      querySelector("#location_id").text = "Location:";
      querySelector("#location_lat_id").text = "lat: ${lat}";
      querySelector("#location_lon_id").text = "lon: ${lon}";
    },
    (err) {
      if (err.code == PositionError.TIMEOUT) {
        querySelector("#location_id").text = "Location: Timeout";
      } else {
        querySelector("#location_id").text = "Location: Failed";
      }
    },
    new GeolocationOptions(frequency:600000, timeout:300000,
                           enableHighAccuracy:true)
  );
}


String showAngularSpeed(CanvasRenderingContext2D context) {
  void drawHorizon(int time) {
    double angle = simpleAngle();
    if (!angle.isNaN) {
      context.clearRect(0, 0, 150, 150);
      context.save();
      context.translate(75, 75);
      context.rotate(angle);
      context.beginPath();
      context.rect(-25, -50, 50, 100);
      context.fill();
      context.stroke();
      context.restore();
    }
  }

  querySelector("#gyro_id").text = "Angular Speed: Looking";
  querySelector("#gyro_x_id").text = "x: ???";
  querySelector("#gyro_y_id").text = "y: ???";
  querySelector("#gyro_z_id").text = "z: ???";
  querySelector("#gyro_angle_id").text = "angle: ???";
  var id = gyroscope.watchAngularSpeed(
    (speed) {
      String x = speed.w.x.toStringAsFixed(2);
      String y = speed.w.y.toStringAsFixed(2);
      String z = speed.w.z.toStringAsFixed(2);
      querySelector("#gyro_id").text = "Angular Speed:";
      querySelector("#gyro_x_id").text = "x: $x";
      querySelector("#gyro_y_id").text = "y: $y";
      querySelector("#gyro_z_id").text = "z: $z";
      updateUpWithAngularSpeed(speed);
      String angle = simpleAngle().toStringAsFixed(3);
      querySelector("#gyro_angle_id").text = "angle: ${angle}";
      ts = speed.timestamp;
      window.requestAnimationFrame(drawHorizon);
    },
    () {
      querySelector("#gyro_id").text = "Gyroscope Fail";
    },
    new GyroscopeOptions(frequency:50)
  );
  return id;
}


void main() {
  var text = querySelector("#status_id");
  text.text = "Initializing.";

  Future<Device> enable = enableDeviceAccess();
  List<double> mdata = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> xdata = [0.0, 0.0, .0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> ydata = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> zdata = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> bdata = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  Line accel_chart = new Line({
    'labels' : ["0", "", "1", "", "2", "", "3", "", "4", "",
                "5", "", "6", "", "7", "", "8", "", "9", "",],
    'datasets' : [{
      'fillColor' : "rgba(220,220,220,0.5)",
      'strokeColor' : "rgba(0,0,0,1)",
      'pointColor' : "rgba(220,220,220,1)",
      'pointStrokeColor' : "#fff",
      'pointDot' : false,
      'data' : mdata
    }, {
      'fillColor' : "rgba(0,0,220,0.5)",
      'strokeColor' : "rgba(0,0,0,1)",
      'pointColor' : "rgba(0,0,220,1)",
      'pointStrokeColor' : "#fff",
      'pointDot' : false,
      'data' : xdata 
    }, {
      'fillColor' : "rgba(0,220,0,0.5)",
      'strokeColor' : "rgba(0,0,0,1)",
      'pointColor' : "rgba(0,220,0,1)",
      'pointStrokeColor' : "#fff",
      'pointDot' : false,
      'data' : ydata 
    }, {
      'fillColor' : "rgba(220,0,0,0.5)",
      'strokeColor' : "rgba(0,0,0,1)",
      'pointColor' : "rgba(220,0,0,1)",
      'pointStrokeColor' : "#fff",
      'pointDot' : false,
      'data' : zdata 
    }]
  }, {
    'titleText': 'Acceleration (m/s^2)',
    'scaleOverride' : true,
    'scaleMinValue' : 0.0, 
    'scaleMaxValue' : 30.0, 
    'scaleStepValue' : null,
    'animation': false,
  });

  Line baro_chart = new Line({
    'labels' : ["0", "", "1", "", "2", "", "3", "", "4", "",
                "5", "", "6", "", "7", "", "8", "", "9", "",],
    'datasets' : [{
      'fillColor' : "rgba(220,220,220,0.5)",
      'strokeColor' : "rgba(0,0,0,1)",
      'pointColor' : "rgba(220,220,220,1)",
      'pointStrokeColor' : "#fff",
      'pointDot' : false,
      'data' : bdata
    }]
  }, {
    'titleText': 'Altitude (m)',
    'scaleOverride' : true, 
    'scaleMinValue' : 0.0, 
    'scaleMaxValue' : 100.0, 
    'scaleStepValue' : null,
    'animation': false,    
  });


  CanvasElement horizon_canvas = querySelector("#horizon_canvas");
  horizon_canvas.width = 150;
  horizon_canvas.height = 150;
  CanvasRenderingContext2D horizon_context = horizon_canvas.getContext('2d');


  enable.then((device) {
    text.text = "";
    var accel_id = showAcceleration(accel_chart, horizon_context,
                                    xdata, ydata, zdata, mdata);
    var pressure_id = showPressure(baro_chart, bdata);
    var location_id = showLocation();
    var gyro_id = showAngularSpeed(horizon_context);
  });
  enable.catchError((ex) {
    text.text = "There was an error: $ex";
  });

  DivElement accel_container = querySelector('#accel_chart_id');
  accel_container.style.height ='150px';
  accel_container.style.width =  '90%';
  accel_chart.show(accel_container);

  DivElement baro_container = querySelector('#baro_chart_id');
  baro_container.style.height ='150px';
  baro_container.style.width =  '90%';
  baro_chart.show(baro_container);
}