enum RedeemStatus { requested, processing, paid }

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
