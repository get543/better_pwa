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
  // Keep this tolerant of older app versions that may not have stored imageUrl
  factory LinkItem.fromJson(Map<String, dynamic> json) => LinkItem(
    title: (json['title'] ?? '').toString(),
    url: (json['url'] ?? '').toString(),
    imageUrl: (json['imageUrl'] ?? '').toString(),
  );
}
