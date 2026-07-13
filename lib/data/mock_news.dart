import '../models/news_article.dart';
import '../models/spotlight_item.dart';

final List<String> categories = [
  'For You',
  'Trending',
  'Latest News',
  'Andhra Pradesh',
  'Telangana',
  'National',
  'International',
  'Politics',
  'Business',
  'Sports',
  'Cinema',
  'Technology',
  'Education & Jobs',
  'Health',
  'Agriculture',
  'Spiritual',
  'Videos',
  'Photos',
];

final List<NewsArticle> mockArticles = [
  NewsArticle(
    id: '1',
    title: 'ISRO Successfully Launches Next-Gen Weather Satellite',
    summary:
        'The satellite will improve monsoon forecasting accuracy across the Indian subcontinent.',
    body:
        'The Indian Space Research Organisation (ISRO) confirmed a successful launch of its latest weather satellite from Sriharikota. Officials said the mission will significantly enhance real-time monsoon tracking, cyclone prediction, and agricultural planning across the country. The satellite carries advanced imaging sensors capable of capturing atmospheric data at higher resolution than previous missions.\n\nScientists expect the first data transmissions within the next 72 hours, with public dashboards expected to go live for farmers and disaster management teams within a month.',
    imageUrl: 'https://images.unsplash.com/photo-1516849841032-87cbac4d88f7?w=800',
    imageUrls: [
      'https://images.unsplash.com/photo-1516849841032-87cbac4d88f7?w=800',
      'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800',
      'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=800',
    ],
    source: 'India Today',
    category: 'National',
    publishedAt: DateTime.now().subtract(const Duration(minutes: 22)),
    likes: 4821,
    comments: 312,
    shares: 588,
    readTimeMinutes: 3,
  ),
  NewsArticle(
    id: '2',
    title: 'Hyderabad Metro Phase 2 Construction to Begin Next Quarter',
    summary:
        'New corridors will connect the outer ring road to the airport, easing traffic congestion.',
    body:
        'The Telangana government has approved funding for Phase 2 of the Hyderabad Metro Rail project. The expansion will add two new corridors covering nearly 70 kilometers, connecting key IT hubs to the Rajiv Gandhi International Airport.\n\nOfficials estimate the project will take four years to complete and is expected to reduce daily commute times by up to 40% for residents in the western and southern parts of the city.',
    imageUrl: 'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=800',
    source: 'Deccan Chronicle',
    category: 'Local',
    publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
    likes: 2210,
    comments: 145,
    shares: 98,
    readTimeMinutes: 2,
  ),
  NewsArticle(
    id: '3',
    title: 'India Clinches Series Win With Stunning Last-Over Finish',
    summary:
        'A six off the final ball sealed a thrilling victory in front of a packed home crowd.',
    body:
        'In a nail-biting finish, India secured the series 3-2 with a last-ball six that sent the stadium into a frenzy. Chasing 187, the middle order collapsed early, but a composed innings in the death overs turned the match around.\n\nThe captain praised the team\'s temperament under pressure, calling it "one of the best chases I have been part of."',
    imageUrl: 'https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=800',
    source: 'ESPN Cricinfo',
    category: 'Sports',
    publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
    likes: 9832,
    comments: 1204,
    shares: 2110,
    readTimeMinutes: 4,
  ),
  NewsArticle(
    id: '4',
    title: 'New AI Chip Promises 3x Faster On-Device Processing',
    summary:
        'The chipset targets budget smartphones, bringing AI features to a wider audience.',
    body:
        'A leading semiconductor manufacturer unveiled a new AI-optimized chipset aimed at mid-range smartphones. The chip reportedly delivers three times the on-device AI processing speed of its predecessor while consuming 20% less power.\n\nIndustry analysts say this could accelerate the rollout of AI-powered camera and translation features to devices priced under 20,000 rupees, a segment that dominates the Indian market.',
    imageUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
    source: 'TechCrunch',
    category: 'Tech',
    publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
    likes: 3456,
    comments: 210,
    shares: 401,
    readTimeMinutes: 3,
  ),
  NewsArticle(
    id: '5',
    title: 'Blockbuster Opens to Record Weekend Collections',
    summary:
        'The film crossed 100 crore in its opening weekend, setting a new benchmark for the year.',
    body:
        'The much-awaited action drama opened to packed theaters across the country, collecting over 100 crore rupees in its first three days. Trade analysts credit the strong word-of-mouth and an aggressive multi-language release strategy for the numbers.\n\nThe film is expected to cross the 200 crore mark within its second week if current trends continue.',
    imageUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800',
    source: 'Filmfare',
    category: 'Entertainment',
    publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
    likes: 15234,
    comments: 2044,
    shares: 3320,
    readTimeMinutes: 2,
  ),
  NewsArticle(
    id: '6',
    title: 'Sensex Hits Fresh All-Time High Amid Strong FII Inflows',
    summary:
        'Banking and IT stocks led the rally as investor sentiment remained upbeat.',
    body:
        'The BSE Sensex closed at a record high today, driven by strong buying in banking and IT heavyweights. Foreign institutional investors poured in over 3,200 crore rupees, marking the fifth consecutive session of net inflows.\n\nMarket experts remain cautiously optimistic, citing stable inflation data and healthy corporate earnings as tailwinds for the coming quarter.',
    imageUrl: 'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?w=800',
    source: 'Economic Times',
    category: 'Business',
    publishedAt: DateTime.now().subtract(const Duration(hours: 15)),
    likes: 1876,
    comments: 98,
    shares: 145,
    readTimeMinutes: 3,
  ),
  NewsArticle(
    id: '7',
    title: 'Heavy Rains Predicted Across Telangana This Week',
    summary:
        'IMD issues an orange alert for several districts starting Thursday.',
    body:
        'The India Meteorological Department has issued an orange alert for Hyderabad and surrounding districts, forecasting heavy to very heavy rainfall over the next four days. Residents in low-lying areas have been advised to take precautions.\n\nDisaster response teams have been placed on standby, and schools in the most affected districts may see revised timings later in the week.',
    imageUrl: 'https://images.unsplash.com/photo-1428592953211-077101b2021b?w=800',
    source: 'The Hindu',
    category: 'Local',
    publishedAt: DateTime.now().subtract(const Duration(hours: 18)),
    likes: 987,
    comments: 76,
    shares: 210,
    readTimeMinutes: 2,
  ),
];

final List<Comment> mockComments = [
  Comment(
    id: 'c1',
    username: 'Rohit Sharma',
    avatarUrl: 'https://i.pravatar.cc/150?u=rohit',
    text: 'This is a fantastic move! Looking forward to seeing the improvements in our daily commute.',
    postedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    likes: 12,
  ),
  Comment(
    id: 'c2',
    username: 'Priya Patel',
    avatarUrl: 'https://i.pravatar.cc/150?u=priya',
    text: 'Finally some good news. The traffic has been unbearable lately.',
    postedAt: DateTime.now().subtract(const Duration(minutes: 15)),
    likes: 8,
  ),
  Comment(
    id: 'c3',
    username: 'Amit Kumar',
    avatarUrl: 'https://i.pravatar.cc/150?u=amit',
    text: 'Hope they finish it on time without the usual delays.',
    postedAt: DateTime.now().subtract(const Duration(hours: 1)),
    likes: 45,
  ),
];

final List<NewsArticle> mockTrendingArticles = [
  mockArticles[1],
  mockArticles[3],
  mockArticles[0],
  mockArticles[2],
];

final List<SpotlightItem> mockSpotlightItems = [
  SpotlightItem.promo(
    id: 'p1',
    imageUrl: 'https://images.unsplash.com/photo-1542204165-65bf26472b9b?w=800',
  ),
  SpotlightItem.poster(
    'poster1',
    'https://images.unsplash.com/photo-1518599904199-0ca897819ddb?w=800', // Example Good morning poster
  ),
  SpotlightItem.standard(mockArticles[0]),
  SpotlightItem.ad('ad1'),
  SpotlightItem.infoCard('info1', 'Today\'s Jyothishyam'),
  SpotlightItem.carousel(
    id: 'c1',
    imageUrls: [
      'https://images.unsplash.com/photo-1516849841032-87cbac4d88f7?w=800',
      'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800',
      'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=800',
    ],
    title: 'Top Weather Updates of the Day',
    baseArticle: mockArticles[0],
  ),
  SpotlightItem.standard(mockArticles[1]),
  SpotlightItem.poster(
    'poster2',
    'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?w=800', // Example quote
  ),
  SpotlightItem.promo(
    id: 'p2',
    imageUrl: 'https://images.unsplash.com/photo-1506744626753-1fa30fd3039d?w=800',
  ),
  SpotlightItem.standard(mockArticles[2]),
  SpotlightItem.ad('ad2'),
  SpotlightItem.infoCard('info2', 'Daily Health Tip'),
  SpotlightItem.standard(mockArticles[3]),
];
