class Holiday {
  final String date;
  final String title;

  Holiday({required this.date, required this.title});

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      date: json['start'], // Sesuai dengan key 'start' dari JSON Laravel kamu
      title: json['title'] ?? 'Libur',
    );
  }
}
