class LinkItem {
  final String title;
  final String url;
  final String imageUrl;

  const LinkItem({
    required this.title,
    required this.url,
    required this.imageUrl,
  });

  // 1. Convert a LinkItem into a Map (JSON format) for storage
  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'imageUrl': imageUrl,
  };

  // 2. Convert a Map from storage back into a LinkItem
  factory LinkItem.fromJson(Map<String, dynamic> json) => LinkItem(
    title: json['title'] as String,
    url: json['url'] as String,
    imageUrl: json['imageUrl'] as String,
  );
}
