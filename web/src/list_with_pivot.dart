class ListWithPivot<T> {
  int pivot = 0;
  List<T> items = [];
  T get selected => items[pivot];

  Map<String, dynamic> toJson() => {
        'pivot': pivot,
        'items': items.map((e) => (e as dynamic).toJson()).toList(),
      };
}
