import 'package:meta/meta.dart';

import 'json.dart';

class ListWithPivot<T extends Json> {
  int pivot = 0;
  List<T> items = [];
  T get selected => items[pivot];

  final Future<T> Function(dynamic json) itemFromJson;

  ListWithPivot({@required this.itemFromJson});

  set selected(T item) {
    pivot = items.indexOf(item);
  }

  Map<String, Object> toJson() => {
        'pivot': pivot,
        'items': items.map((e) => e.toJson()).toList(),
      };

  Future<void> fromJson(json) async {
    pivot = json['pivot'];

    var doActually = true;

    for (var j in json['items']) {
      var i = await itemFromJson(j);
      if (i == null) {
        doActually = false;
      } else if (doActually) {
        items.add(i);
      }
    }
  }
}
