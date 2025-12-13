class ReflectionEntry {
  final DateTime date;
  final int mood; // 1=😞 2=😐 3=😊
  final int rating; // 1-5
  final String worked;
  final String notWorked;

  ReflectionEntry({
    required this.date,
    required this.mood,
    required this.rating,
    required this.worked,
    required this.notWorked,
  });
}
