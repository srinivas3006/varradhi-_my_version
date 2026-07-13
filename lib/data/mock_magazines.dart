class Magazine {
  final String title;
  final String topic;
  final String coverUrl;
  final String issueDate;

  const Magazine({
    required this.title,
    required this.topic,
    required this.coverUrl,
    required this.issueDate,
  });
}

final List<Magazine> mockMagazines = [
  const Magazine(
    title: 'Wanderlust Weekly',
    topic: 'Travel',
    coverUrl:
        'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=600',
    issueDate: 'July 2026 Issue',
  ),
  const Magazine(
    title: 'Vital Signs',
    topic: 'Health',
    coverUrl:
        'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=600',
    issueDate: 'July 2026 Issue',
  ),
  const Magazine(
    title: 'Money Matters',
    topic: 'Finance',
    coverUrl:
        'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=600',
    issueDate: 'July 2026 Issue',
  ),
  const Magazine(
    title: 'Field & Farm',
    topic: 'Agriculture',
    coverUrl:
        'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=600',
    issueDate: 'July 2026 Issue',
  ),
  const Magazine(
    title: 'Glow Guide',
    topic: 'Beauty',
    coverUrl:
        'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=600',
    issueDate: 'July 2026 Issue',
  ),
];
