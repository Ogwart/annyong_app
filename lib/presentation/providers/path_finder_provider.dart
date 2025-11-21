import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:annyong/domain/usecases/path_finder.dart';
import 'package:annyong/domain/usecases/graph_loader.dart';

final pathFinderProvider = FutureProvider<PathFinder>((ref) async {
  return await GraphLoader.loadFromAssets();
});
