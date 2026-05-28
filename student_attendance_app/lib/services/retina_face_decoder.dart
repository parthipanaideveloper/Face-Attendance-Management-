import 'dart:math';
import 'package:flutter/foundation.dart';

/// A custom Dart implementation of RetinaFace Anchor Decoder.
/// This file contains the heavy math required to decode raw TFLite tensors into bounding boxes and landmarks.
/// Note: You MUST provide a valid `retinaface.tflite` model in your assets folder to use this.
class RetinaFaceDecoder {
  final List<List<int>> featureMaps = [[40, 30], [20, 15], [10, 8]]; // Example for 320x240 input
  final List<List<int>> minSizes = [[16, 32], [64, 128], [256, 512]];
  final List<int> steps = [8, 16, 32];
  final List<double> variance = [0.1, 0.2];

  List<List<double>> generatePriors(int imageWidth, int imageHeight) {
    List<List<double>> anchors = [];
    for (int k = 0; k < featureMaps.length; k++) {
      var fmap = featureMaps[k];
      var minSize = minSizes[k];
      for (int i = 0; i < fmap[0]; i++) {
        for (int j = 0; j < fmap[1]; j++) {
          for (var size in minSize) {
            double sKx = size / imageWidth;
            double sKy = size / imageHeight;
            double cx = (j + 0.5) * steps[k] / imageWidth;
            double cy = (i + 0.5) * steps[k] / imageHeight;
            anchors.add([cx, cy, sKx, sKy]);
          }
        }
      }
    }
    return anchors;
  }

  List<List<double>> decodeBoundingBoxes(List<List<double>> locs, List<List<double>> priors) {
    List<List<double>> boxes = [];
    for (int i = 0; i < locs.length; i++) {
      double cx = priors[i][0] + locs[i][0] * variance[0] * priors[i][2];
      double cy = priors[i][1] + locs[i][1] * variance[0] * priors[i][3];
      double w = priors[i][2] * exp(locs[i][2] * variance[1]);
      double h = priors[i][3] * exp(locs[i][3] * variance[1]);
      boxes.add([
        cx - w / 2, // xMin
        cy - h / 2, // yMin
        cx + w / 2, // xMax
        cy + w / 2  // yMax
      ]);
    }
    return boxes;
  }

  List<List<double>> decodeLandmarks(List<List<double>> rawLandmarks, List<List<double>> priors) {
    List<List<double>> landmarks = [];
    for (int i = 0; i < rawLandmarks.length; i++) {
      List<double> pt = [];
      for (int j = 0; j < 5; j++) {
        double px = priors[i][0] + rawLandmarks[i][j * 2] * variance[0] * priors[i][2];
        double py = priors[i][1] + rawLandmarks[i][j * 2 + 1] * variance[0] * priors[i][3];
        pt.add(px);
        pt.add(py);
      }
      landmarks.add(pt);
    }
    return landmarks;
  }
}
