class Poll {
  final String id;
  final String question;
  final List<String> options;
  final List<int> votes;
  int? selectedOption;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    this.selectedOption,
  });

  int get totalVotes => votes.fold(0, (sum, v) => sum + v);

  double percentFor(int index) {
    if (totalVotes == 0) return 0;
    return votes[index] / totalVotes;
  }
}
