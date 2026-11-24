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
  static final _uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false);
  bool get canVote => isVoteId(id) || isLegacyChoice(id);
  static bool isVoteId(String id) => _uuid.hasMatch(id);
  static bool isLegacyChoice(String id) => id == 'a' || id == 'b';

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

enum PollCoverage {
  global,
  state,
  district,
  mandal,
  village,
  municipality,
  assembly;

  static PollCoverage? fromWire(String? value) =>
      values.where((coverage) => coverage.name == value).firstOrNull;
}

class Poll {
  final String id;
  final String question;
  final List<PollOption> optionItems;
  final List<String> options;
  final List<int> votes;
  final int? selectedOption;
  final String? selectedOptionId;
  final Object? userVote;
  final int totalVotes;
  final String? coverageLevel;
  final String? stateId;
  final String? districtId;
  final String? subdistrictId;
  final String? villageId;
  final String? regionId;
  PollCoverage? get coverage => PollCoverage.fromWire(coverageLevel);
  final Map<String, double> percentages;
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
    this.userVote,
    this.coverageLevel,
    this.stateId,
    this.districtId,
    this.subdistrictId,
    this.villageId,
    this.regionId,
    this.percentages = const {},
    int? totalVotes,
    this.isActive = true,
    this.isExpired = false,
    this.endsAt,
    this.createdAt,
  }) : totalVotes =
            totalVotes ?? votes.fold<int>(0, (int sum, int v) => sum + v);

  double percentFor(int index) {
    if (index >= 0 && index < optionItems.length) {
      return optionItems[index].percentage / 100.0;
    }
    if (totalVotes == 0) return 0.0;
    if (index >= votes.length) return 0.0;
    return votes[index] / totalVotes;
  }

  bool get hasVoted =>
      userVote != null || selectedOptionId != null || selectedOption != null;
  bool get closed =>
      !isActive ||
      isExpired ||
      (endsAt != null && !endsAt!.isAfter(DateTime.now()));

  factory Poll.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final rawPercentages = json['percentages'];
    final percentages = <String, double>{
      if (rawPercentages is Map)
        for (final entry in rawPercentages.entries)
          entry.key.toString(): _toDouble(entry.value),
    };
    List<PollOption> optionItems = [];
    List<String> options = [];
    List<int> votes = [];

    if (rawOptions is List) {
      for (var o in rawOptions) {
        if (o is Map<String, dynamic>) {
          final opt = PollOption.fromJson({
            ...o,
            'percentage': o['percentage'] ?? percentages[o['id']?.toString()],
          });
          if (opt.id.isNotEmpty && opt.label.isNotEmpty) optionItems.add(opt);
        }
      }
      optionItems.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      options = optionItems.map((item) => item.label).toList();
      votes = optionItems.map((item) => item.voteCount).toList();
    } else if (json['option_a'] != null && json['option_b'] != null) {
      final optA = json['option_a'].toString();
      final optB = json['option_b'].toString();
      final voteA = _toInt(json['vote_a_count'], 0);
      final voteB = _toInt(json['vote_b_count'], 0);
      final percA = _toDouble(
          json['percentages'] is Map ? json['percentages']['a'] : null, 0.0);
      final percB = _toDouble(
          json['percentages'] is Map ? json['percentages']['b'] : null, 0.0);

      optionItems = [
        PollOption(
            id: 'a',
            label: optA,
            sortOrder: 0,
            voteCount: voteA,
            percentage: percA),
        PollOption(
            id: 'b',
            label: optB,
            sortOrder: 1,
            voteCount: voteB,
            percentage: percB),
      ];
      options = [optA, optB];
      votes = [voteA, voteB];
    }

    int? selectedIdx;
    final rawSelected = json['user_vote_option_id']?.toString().trim();
    final selectedOptId = rawSelected?.isNotEmpty == true ? rawSelected : null;
    final userVote = json['user_vote']?.toString().toLowerCase();

    if (selectedOptId != null) {
      final idx = optionItems.indexWhere((o) => o.id == selectedOptId);
      if (idx != -1) selectedIdx = idx;
    }
    if (selectedIdx == null && selectedOptId == null && userVote != null) {
      final matching =
          optionItems.indexWhere((o) => o.id.toLowerCase() == userVote);
      if (matching >= 0) {
        selectedIdx = matching;
      } else if (userVote == 'a' &&
          (rawOptions is! List || options.length == 2)) {
        selectedIdx = 0;
      } else if (userVote == 'b' && options.length == 2) {
        selectedIdx = 1;
      } else {
        final idx = int.tryParse(userVote);
        if (idx != null && idx >= 0 && idx < options.length) selectedIdx = idx;
      }
    }

    final total = _toInt(json['total_votes']);

    return Poll(
      id: json['id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      options: options,
      votes: votes,
      optionItems: optionItems,
      selectedOption: selectedIdx,
      selectedOptionId: selectedOptId ??
          (selectedIdx != null && selectedIdx < optionItems.length
              ? optionItems[selectedIdx].id
              : null),
      totalVotes: total,
      userVote: json['user_vote'],
      coverageLevel: json['coverage_level']?.toString(),
      stateId: json['state_id']?.toString(),
      districtId: json['district_id']?.toString(),
      subdistrictId: json['subdistrict_id']?.toString(),
      villageId: json['village_id']?.toString(),
      regionId: json['region_id']?.toString(),
      percentages: Map.unmodifiable(percentages),
      isActive: json['is_active'] != false,
      isExpired: json['is_expired'] == true,
      endsAt: DateParser.tryParse(json['ends_at']),
      createdAt: DateParser.tryParse(json['created_at']),
    );
  }
}
