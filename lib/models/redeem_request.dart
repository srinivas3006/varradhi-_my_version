enum RedeemStatus { requested, processing, paid, rejected }

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
      lifetimeEarnedCoins: (json['lifetime_earned_coins'] as num?)?.toInt() ?? 0,
      coinValueRupees: double.tryParse(json['coin_value_rupees']?.toString() ?? '1.0') ?? 1.0,
      availableValueRupees: double.tryParse(json['available_value_rupees']?.toString() ?? '0.0') ?? 0.0,
      minimumWithdrawalCoins: (json['minimum_withdrawal_coins'] as num?)?.toInt() ?? 100,
    );
  }
}

class RewardPayout {
  final String id;
  final int coinsRequested;
  final double valueRupees;
  final String payoutMethod;
  final String? payoutMobile;
  final String? payoutUpiId;
  final String? payoutAccountName;
  final String status;
  final String? userNotes;
  final DateTime createdAt;

  RewardPayout({
    required this.id,
    required this.coinsRequested,
    required this.valueRupees,
    required this.payoutMethod,
    this.payoutMobile,
    this.payoutUpiId,
    this.payoutAccountName,
    required this.status,
    this.userNotes,
    required this.createdAt,
  });

  factory RewardPayout.fromJson(Map<String, dynamic> json) {
    return RewardPayout(
      id: json['id']?.toString() ?? '',
      coinsRequested: (json['coins_requested'] as num?)?.toInt() ?? 0,
      valueRupees: double.tryParse(json['value_rupees']?.toString() ?? '0.0') ??
          ((json['coins_requested'] as num?)?.toDouble() ?? 0.0),
      payoutMethod: json['payout_method']?.toString() ?? 'UPI',
      payoutMobile: json['payout_mobile']?.toString(),
      payoutUpiId: json['payout_upi_id']?.toString(),
      payoutAccountName: json['payout_account_name']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      userNotes: json['user_notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  RedeemStatus get parsedStatus {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return RedeemStatus.paid;
      case 'processing':
        return RedeemStatus.processing;
      case 'rejected':
        return RedeemStatus.rejected;
      case 'pending':
      case 'requested':
      default:
        return RedeemStatus.requested;
    }
  }
}

