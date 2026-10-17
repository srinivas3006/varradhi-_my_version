enum RedeemStatus { requested, processing, paid, rejected, cancelled }

class RedeemRequest {
  final String id;
  final int tokensRedeemed;
  final int amountRupees;
  final String upiId;
  RedeemStatus status;
  final DateTime requestedAt;

  RedeemRequest({
    required this.id,
    required this.tokensRedeemed,
    required this.amountRupees,
    required this.upiId,
    this.status = RedeemStatus.requested,
    required this.requestedAt,
  });
}

class RewardWallet {
  final int availableCoins;
  final int lockedCoins;
  final int redeemedCoins;
  final int lifetimeEarnedCoins;
  final double coinValueRupees;
  final double availableValueRupees;
  final int minimumWithdrawalCoins;

  RewardWallet({
    required this.availableCoins,
    required this.lockedCoins,
    required this.redeemedCoins,
    required this.lifetimeEarnedCoins,
    required this.coinValueRupees,
    required this.availableValueRupees,
    required this.minimumWithdrawalCoins,
  });

  factory RewardWallet.fromJson(Map<String, dynamic> json) {
    return RewardWallet(
      availableCoins: (json['available_coins'] as num?)?.toInt() ?? 0,
      lockedCoins: (json['locked_coins'] as num?)?.toInt() ?? 0,
      redeemedCoins: (json['redeemed_coins'] as num?)?.toInt() ?? 0,
      lifetimeEarnedCoins:
          (json['lifetime_earned_coins'] as num?)?.toInt() ?? 0,
      coinValueRupees:
          double.tryParse(json['coin_value_rupees']?.toString() ?? '1.0') ??
              1.0,
      availableValueRupees: double.tryParse(
              json['available_value_rupees']?.toString() ?? '0.0') ??
          0.0,
      minimumWithdrawalCoins:
          (json['minimum_withdrawal_coins'] as num?)?.toInt() ?? 100,
    );
  }
}

/// First money value found under [keys] ("5.00", 5, "₹5"), or null.
double? _rupeesFrom(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    if (v is num) return v.toDouble();
    final parsed =
        double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.\-]'), ''));
    if (parsed != null) return parsed;
  }
  return null;
}

String? _text(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k]?.toString().trim();
    if (v != null && v.isNotEmpty && v != 'null') return v;
  }
  return null;
}

DateTime? _date(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final d = DateTime.tryParse(v.toString());
    if (d != null) return d;
  }
  return null;
}

class RewardPayout {
  final String id;
  final int coinsRequested;

  /// The payout's rupee amount as the backend sent it, or null when it sent
  /// none — then [amountFor] works it out from the coin value. Reading a
  /// missing amount as 0 showed every withdrawal as "₹0.00".
  final double? valueRupees;
  final String payoutMethod;
  final String? payoutMobile;
  final String? payoutUpiId;
  final String? payoutAccountName;
  final String status;
  final String? userNotes;

  /// Why it was rejected, or the admin's note.
  final String? adminNotes;

  /// Bank / UPI reference once paid.
  final String? reference;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final DateTime? rejectedAt;

  RewardPayout({
    required this.id,
    required this.coinsRequested,
    this.valueRupees,
    required this.payoutMethod,
    this.payoutMobile,
    this.payoutUpiId,
    this.payoutAccountName,
    required this.status,
    this.userNotes,
    this.adminNotes,
    this.reference,
    required this.createdAt,
    this.approvedAt,
    this.paidAt,
    this.rejectedAt,
  });

  factory RewardPayout.fromJson(Map<String, dynamic> json) {
    return RewardPayout(
      id: json['id']?.toString() ?? '',
      coinsRequested: (json['coins_requested'] as num?)?.toInt() ??
          (json['coins'] as num?)?.toInt() ??
          0,
      valueRupees: _rupeesFrom(json, const [
        'value_rupees',
        'amount_rupees',
        'payout_amount',
        'amount',
      ]),
      payoutMethod: json['payout_method']?.toString() ?? 'UPI',
      payoutMobile: _text(json, const ['payout_mobile']),
      payoutUpiId: _text(json, const ['payout_upi_id', 'upi_id']),
      payoutAccountName: _text(json, const ['payout_account_name']),
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      userNotes: _text(json, const ['user_notes']),
      adminNotes: _text(json, const [
        'rejection_reason',
        'admin_notes',
        'admin_note',
        'review_note',
        'notes',
      ]),
      reference: _text(json, const [
        'transaction_reference',
        'payment_reference',
        'utr',
        'reference',
      ]),
      createdAt:
          _date(json, const ['requested_at', 'created_at']) ?? DateTime.now(),
      approvedAt: _date(json, const ['approved_at']),
      paidAt: _date(json, const ['paid_at', 'processed_at', 'completed_at']),
      rejectedAt: _date(json, const ['rejected_at', 'cancelled_at']),
    );
  }

  /// The rupee amount: the backend's, else coins × [coinValue].
  double amountFor(double coinValue) => valueRupees != null && valueRupees! > 0
      ? valueRupees!
      : coinsRequested * coinValue;

  /// Where the money goes: UPI ID, else mobile, else account name.
  String get destination =>
      payoutUpiId ?? payoutMobile ?? payoutAccountName ?? '';

  RedeemStatus get parsedStatus {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return RedeemStatus.paid;
      case 'processing':
      case 'approved':
        return RedeemStatus.processing;
      case 'rejected':
      case 'failed':
        return RedeemStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return RedeemStatus.cancelled;
      case 'pending':
      case 'requested':
      default:
        return RedeemStatus.requested;
    }
  }
}

/// What a coin ledger line did, from the backend's `transaction_type`.
enum RewardTxKind {
  /// EARN_APPROVED_UGC_MEDIA — an approved story with a photo or video.
  earn,

  /// WITHDRAWAL_HOLD — coins set aside for a withdrawal request.
  hold,

  /// WITHDRAWAL_RELEASE — a rejected / cancelled request's coins returned.
  release,

  /// WITHDRAWAL_PAID — the held coins were paid out.
  paid,
  adminCredit,
  adminDebit,
  other,
}

/// One line of the coin ledger (GET /api/v1/rewards/transactions/):
/// coins earned for an approved story, coins held for a withdrawal,
/// coins paid out or returned, admin adjustments.
class RewardTransaction {
  final String id;

  /// `earned`, `locked`, `redeemed`, `released`, `reversed`, `adjustment`…
  final String type;

  /// Signed by the backend where it can be; see [isCredit].
  final int coins;
  final double? valueRupees;
  final String status;
  final String sourceApp;
  final String? sourceObjectId;

  /// The story's title when the backend includes it in metadata.
  final String? title;
  final String? note;
  final DateTime createdAt;

  RewardTransaction({
    required this.id,
    required this.type,
    required this.coins,
    this.valueRupees,
    required this.status,
    required this.sourceApp,
    this.sourceObjectId,
    this.title,
    this.note,
    required this.createdAt,
  });

  factory RewardTransaction.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const <String, dynamic>{};
    return RewardTransaction(
      id: json['id']?.toString() ?? '',
      type: (json['transaction_type'] ?? json['type'] ?? 'earned')
          .toString()
          .toLowerCase(),
      coins: (json['coins'] as num?)?.toInt() ??
          int.tryParse(json['coins']?.toString() ?? '') ??
          0,
      valueRupees: _rupeesFrom(json, const ['value_rupees', 'amount_rupees']),
      status: (json['status'] ?? 'completed').toString().toLowerCase(),
      sourceApp: (json['source_app'] ?? '').toString().toLowerCase(),
      sourceObjectId: json['source_object_id']?.toString(),
      title: _text(meta, const [
            'title',
            'submission_title',
            'article_title',
            'headline',
          ]) ??
          _text(json, const ['title', 'description']),
      note: _text(meta, const ['reason', 'note', 'notes']) ??
          _text(json, const ['note', 'notes']),
      createdAt: _date(json, const ['created_at']) ?? DateTime.now(),
    );
  }

  RewardTxKind get kind {
    switch (type) {
      case 'earn_approved_ugc_media':
      case 'earned':
        return RewardTxKind.earn;
      case 'withdrawal_hold':
      case 'locked':
        return RewardTxKind.hold;
      case 'withdrawal_release':
      case 'released':
        return RewardTxKind.release;
      case 'withdrawal_paid':
      case 'redeemed':
        return RewardTxKind.paid;
      case 'admin_credit':
        return coins < 0 ? RewardTxKind.adminDebit : RewardTxKind.adminCredit;
      case 'admin_debit':
        return RewardTxKind.adminDebit;
      default:
        if (type.startsWith('earn')) return RewardTxKind.earn;
        return RewardTxKind.other;
    }
  }

  /// Coins added to the available balance (earned, returned, admin credit).
  bool get isCredit => switch (kind) {
        RewardTxKind.earn ||
        RewardTxKind.release ||
        RewardTxKind.adminCredit =>
          true,
        RewardTxKind.other => coins >= 0,
        _ => false,
      };

  /// A payout: the coins already left the balance at [RewardTxKind.hold],
  /// so this line is shown without a +/- sign.
  bool get isNeutral => kind == RewardTxKind.paid;

  int get absCoins => coins.abs();

  double amountFor(double coinValue) =>
      valueRupees != null && valueRupees!.abs() > 0
          ? valueRupees!.abs()
          : absCoins * coinValue;
}
