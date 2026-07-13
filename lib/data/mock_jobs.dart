import '../models/job_listing.dart';

final List<JobListing> mockJobs = [
  const JobListing(
    title: 'Staff Nurse — 240 vacancies',
    organization: 'Telangana Vaidya Vidhana Parishad',
    location: 'Hyderabad, Telangana',
    type: 'Government',
    lastDate: '15 Jul 2026',
    vacancies: '240',
  ),
  const JobListing(
    title: 'Probationary Officer',
    organization: 'State Bank of India',
    location: 'Pan India',
    type: 'Bank',
    lastDate: '20 Jul 2026',
    vacancies: '1,800',
  ),
  const JobListing(
    title: 'Junior Assistant',
    organization: 'Telangana State Public Service Commission',
    location: 'Telangana',
    type: 'Government',
    lastDate: '30 Jul 2026',
    vacancies: '503',
  ),
  const JobListing(
    title: 'Software Engineer — Freshers',
    organization: 'TCS NQT Drive',
    location: 'Multiple Cities',
    type: 'Private',
    lastDate: '10 Jul 2026',
    vacancies: '5,000',
  ),
  const JobListing(
    title: 'Constable Recruitment',
    organization: 'Telangana Police',
    location: 'Telangana',
    type: 'Government',
    lastDate: '25 Jul 2026',
    vacancies: '3,200',
  ),
];

final List<Map<String, String>> mockLocalServices = [
  {
    'name': 'Sri Balaji Electricians',
    'category': 'Electrician',
    'area': 'Ameerpet, Hyderabad',
    'rating': '4.6',
  },
  {
    'name': 'QuickFix Plumbing',
    'category': 'Plumber',
    'area': 'Kukatpally, Hyderabad',
    'rating': '4.3',
  },
  {
    'name': 'CleanHome Pest Control',
    'category': 'Pest Control',
    'area': 'Madhapur, Hyderabad',
    'rating': '4.7',
  },
  {
    'name': 'Metro Packers & Movers',
    'category': 'Packers & Movers',
    'area': 'Gachibowli, Hyderabad',
    'rating': '4.4',
  },
  {
    'name': 'FreshCuts Salon',
    'category': 'Salon',
    'area': 'Banjara Hills, Hyderabad',
    'rating': '4.8',
  },
];
