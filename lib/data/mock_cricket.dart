class CricketMatch {
  final String team1;
  final String team2;
  final String team1Score;
  final String team2Score;
  final String status; // e.g. "Live", "Upcoming", "Completed"
  final String note; // e.g. "India needs 42 off 30 balls"
  final String venue;
  final String matchTime;

  const CricketMatch({
    required this.team1,
    required this.team2,
    required this.team1Score,
    required this.team2Score,
    required this.status,
    required this.note,
    required this.venue,
    required this.matchTime,
  });
}

final List<CricketMatch> mockMatches = [
  const CricketMatch(
    team1: 'India',
    team2: 'Australia',
    team1Score: '187/4 (18.2 ov)',
    team2Score: 'Yet to bat',
    status: 'Live',
    note: 'India need 29 runs in 10 balls',
    venue: 'Rajiv Gandhi Stadium, Hyderabad',
    matchTime: 'Today, 7:00 PM',
  ),
  const CricketMatch(
    team1: 'England',
    team2: 'South Africa',
    team1Score: '256/8 (50 ov)',
    team2Score: '198/10 (44.3 ov)',
    status: 'Completed',
    note: 'England won by 58 runs',
    venue: 'The Oval, London',
    matchTime: 'Yesterday',
  ),
  const CricketMatch(
    team1: 'Pakistan',
    team2: 'New Zealand',
    team1Score: '-',
    team2Score: '-',
    status: 'Upcoming',
    note: 'Match starts in 2 days',
    venue: 'Gaddafi Stadium, Lahore',
    matchTime: 'Fri, 3:30 PM',
  ),
];
