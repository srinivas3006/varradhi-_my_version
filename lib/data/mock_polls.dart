import '../models/poll.dart';

final List<Poll> mockPolls = [
  Poll(
    id: 'p1',
    question: 'Should the metro network be prioritized over new highways?',
    options: ['Yes, metro first', 'No, highways first', 'Both equally'],
    votes: [4210, 1890, 2760],
  ),
  Poll(
    id: 'p2',
    question: 'Will India retain the series lead in the next match?',
    options: ['Yes', 'No', 'Too close to call'],
    votes: [6120, 1240, 3330],
  ),
  Poll(
    id: 'p3',
    question: 'Is AI improving your daily productivity?',
    options: ['Significantly', 'Somewhat', 'Not really'],
    votes: [2980, 4110, 990],
  ),
];
