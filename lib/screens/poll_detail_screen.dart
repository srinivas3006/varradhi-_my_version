import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/poll_card.dart';

/// A single poll, opened from a https://vaaradhinews.com/poll/{id}/ link or a
/// poll notification. The card loads it for the reader on the current route.
class PollDetailScreen extends StatelessWidget {
  const PollDetailScreen({super.key, required this.pollId});

  final String pollId;

  @override
  Widget build(BuildContext context) {
    final telugu = AppState.instance.language == 'Telugu';
    return Scaffold(
      appBar: AppBar(title: Text(telugu ? 'పోల్' : 'Poll')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PollCard.detail(pollId: pollId),
        ),
      ),
    );
  }
}
