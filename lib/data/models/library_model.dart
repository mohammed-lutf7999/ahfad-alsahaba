class LibraryItem {
  final String id;
  final String title;
  final String content;

  LibraryItem({required this.id, required this.title, required this.content});

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
    );
  }
}

class LibrarySection {
  final String id;
  final String title;
  final dynamic icon; // IconData or String asset path
  final List<LibraryItem> items;

  LibrarySection({required this.id, required this.title, required this.icon, required this.items});
}
