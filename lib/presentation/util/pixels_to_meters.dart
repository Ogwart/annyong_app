import 'dart:math';

double pixelsToMeters(double pixels) {
  return pixels / 10;
}

// 두 점의 좌표 -> 미터 길이
double pointsToMeters(double srcX, double srcY, double dstX, double dstY) {
  return sqrt(pow(srcX - dstX, 2) + pow(srcY - dstY, 2)) / 10;
}
