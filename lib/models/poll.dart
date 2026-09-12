import '../core/utils/date_parser.dart';

int _toInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString().trim()) ?? fallback;
}

double _toDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is double) return val;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString().trim()) ?? fallback;
}

class PollOption {
  final String id;
  final String label;
  final int sortOrder;
  final int voteCount;
  final double percentage;

  PollOption({
    required this.id,
    required this.label,
    this.sortOrder = 0,
    this.voteCount = 0,
    this.percentage = 0.0,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sortOrder: _toInt(json['sort_order'], 0),
      voteCount: _toInt(json['vote_count'], 0),
      percentage: _toDouble(json['percentage'], 0.0),
    );
  }
}

class Poll {
  final String id;
  final String question;
  final List<PollOption> optionItems;
  final List<String> options;
  final List<int> votes;
  int? selectedOption;
  String? selectedOptionId;
  int totalVotes;
  final bool isActive;
  final bool isExpired;
  final DateTime? endsAt;
  final DateTime? createdAt;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    this.optionItems = const [],
    this.selectedOption,
    this.selectedOptionId,
    int? totalVotes,
    this.isActive = true,
    this.isExpired = false,
    this.endsAt,
    this.createdAt,
  }) : totalVotes = totalVotes ?? votes.fold<int>(0, (int sum, int v) => sum + v);

  double percentFor(int index) {
    if (optionItems.isNotEmpty && index < optionItems.length) {
      final p = optionItems[index].percentage;
      if (p > 0) return p / 100.0;
    }
    if (totalVotes == 0) return 0.0;
    if (index >= votes.length) return 0.0;
    return votes[index] / totalVotes;
  }

  factory Poll.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List?;
    List<PollOption> optionItems = [];
    List<String> options = [];
    List<int> votes = [];

    if (rawOptions != null && rawOptions.isNotEmpty) {
      for (var o in rawOptions) {
        if (o is Map<String, dynamic>) {
          final opt = PollOption.fromJson(o);
          optionItems.add(opt);
          options.add(opt.label);
          votes.add(opt.voteCount);
        }
      }
    } else {
      final optA = json['option_a']?.toString() ?? 'A';
      final optB = json['option_b']?.toString() ?? 'B';
      final voteA = _toInt(json['vote_a_count'], 0);
      final voteB = _toInt(json['vote_b_count'], 0);
      final percA = _toDouble(json['percentages'] is Map ? json['percentages']['a'] : null, 0.0);
      final percB = _toDouble(json['percentages'] is Map ? json['percentages']['b'] : null, 0.0);

      optionItems = [
        PollOption(id: 'a', label: optA, sortOrder: 0, voteCount: voteA, percentage: percA),
        PollOption(id: 'b', label: optB, sortOrder: 1, voteCount: voteB, percentage: percB),
      ];
      options = [optA, optB];
      votes = [voteA, voteB];
    }

    int? selectedIdx;
    String? selectedOptId = json['user_vote_option_id']?.toString();
    final userVote = json['user_vote']?.toString().toLowerCase();

    if (selectedOptId != null) {
      final idx = optionItems.indexWhere((o) => o.id == selectedOptId);
      if (idx != -1) selectedIdx = idx;
    }
    if (selectedIdx == null && userVote != null) {
      if (userVote == 'a') {
        selectedIdx = 0;
      } else if (userVote == 'b') {
        selectedIdx = 1;
      } else {
        final idx = int.tryParse(userVote);
        if (idx != null && idx >= 0 && idx < options.length) selectedIdx = idx;
      }
    }

    final total = _toInt(json['total_votes'], votes.fold<int>(0, (int sum, int v) => sum + v));

    return Poll(
      id: json['id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      options: options,
      votes: votes,
      optionItems: optionItems,
      selectedOption: selectedIdx,
      selectedOptionId: selectedOptId ??
          (selectedIdx != null && selectedIdx < optionItems.length ? optionItems[selectedIdx].id : null),
      totalVotes: total,
      isActive: json['is_active'] != false,
      isExpired: json['is_expired'] == true,
      endsAt: DateParser.tryParse(json['ends_at']),
      createdAt: DateParser.tryParse(json['created_at']),
    );
  }
}
