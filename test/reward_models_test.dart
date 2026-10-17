import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/redeem_request.dart';

void main() {
  group('RewardPayout', () {
    test('a missing amount is worked out from coins, not shown as ₹0', () {
      final p = RewardPayout.fromJson({
        'id': '1',
        'coins_requested': 120,
        'status': 'pending',
        'payout_upi_id': 'me@upi',
        'created_at': '2026-10-10T10:00:00Z',
      });
      expect(p.valueRupees, isNull);
      expect(p.amountFor(0.5), 60);
      expect(p.destination, 'me@upi');
      expect(p.parsedStatus, RedeemStatus.requested);
    });

    test('backend amount, reference, paid date and reason are read', () {
      final p = RewardPayout.fromJson({
        'id': '2',
        'coins_requested': 100,
        'value_rupees': '100.00',
        'status': 'PAID',
        'transaction_reference': 'UTR123',
        'paid_at': '2026-10-12T08:00:00Z',
        'created_at': '2026-10-10T10:00:00Z',
      });
      expect(p.amountFor(0.5), 100);
      expect(p.reference, 'UTR123');
      expect(p.paidAt, isNotNull);
      expect(p.parsedStatus, RedeemStatus.paid);

      final r = RewardPayout.fromJson({
        'id': '3',
        'coins_requested': 100,
        'status': 'rejected',
        'rejection_reason': 'Wrong UPI ID',
      });
      expect(r.parsedStatus, RedeemStatus.rejected);
      expect(r.adminNotes, 'Wrong UPI ID');
      expect(
          RewardPayout.fromJson({'status': 'approved'}).parsedStatus,
          RedeemStatus.processing);
    });
  });

  group('RewardTransaction', () {
    test('earned coins for a story are a credit with its title', () {
      final t = RewardTransaction.fromJson({
        'id': 't1',
        'transaction_type': 'EARNED',
        'coins': 10,
        'source_app': 'ugc',
        'metadata': {'submission_title': 'Road repaired'},
        'created_at': '2026-10-01T09:00:00Z',
      });
      expect(t.isCredit, isTrue);
      expect(t.title, 'Road repaired');
      expect(t.amountFor(1), 10);
    });

    test('locked / redeemed / negative lines are debits', () {
      for (final type in ['locked', 'redeemed']) {
        expect(
            RewardTransaction.fromJson({'transaction_type': type, 'coins': 50})
                .isCredit,
            isFalse);
      }
      final neg = RewardTransaction.fromJson(
          {'transaction_type': 'adjustment', 'coins': -5});
      expect(neg.isCredit, isFalse);
      expect(neg.absCoins, 5);
    });
  });
}
