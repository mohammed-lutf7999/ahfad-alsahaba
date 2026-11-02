/// نموذج المقولة
class Quote {
  final String id;
  final String title;        // عنوان المقولة
  final String author;       // القائل
  final String text;         // نص المقولة
  final String reference;    // المرجع
  final String? category;    // تصنيف اختياري

  Quote({
    required this.id,
    required this.title,
    required this.author,
    required this.text,
    required this.reference,
    this.category,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      text: json['text'] ?? '',
      reference: json['reference'] ?? '',
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'text': text,
      'reference': reference,
      'category': category,
    };
  }
}
