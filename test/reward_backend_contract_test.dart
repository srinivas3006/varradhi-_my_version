import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaaradhi/models/redeem_request.dart';
import 'package:vaaradhi/screens/redeem_request_screen.dart';

/// Rewards API handover from the backend (Oct 2026).
void main() {
  test('wallet: rupee values arrive as strings', () {
    final w = RewardWallet.fromJson({
      'available_coins': 12,
      'locked_coins': 2,
      'redeemed_coins': 5,
      'lifetime_earned_coins': 19,
      'coin_value_rupees': '5.00',
      'available_value_rupees': '60.00',
      'minimum_withdrawal_coins': 5,
    });
    expect(w.coinValueRupees, 5);
    expect(w.availableValueRupees, 60);
    expect(w.minimumWithdrawalCoins, 5);
  });

  test('created payout: amount_rupees, requested_at, payment_reference', () {
    final p = RewardPayout.fromJson({
      'id': 'payout-uuid',
      'coins_requested': 5,
      'coin_value_rupees': '5.00',
      'amount_rupees': '25.00',
      'payout_method': 'UPI',
      'payout_mobile': '',
      'payout_upi_id': 'user@upi',
      'payout_account_name': 'Ganesh',
      'status': 'PENDING',
      'payment_reference': '',
      'requested_at': '2026-10-15T12:00:00+05:30',
      'approved_at': null,
      'paid_at': null,
      'rejected_at': null,
    });
    expect(p.amountFor(1), 25);
    expect(p.destination, 'user@upi');
    expect(p.reference, isNull, reason: 'empty reference is not shown');
    expect(p.createdAt.toUtc(), DateTime.utc(2026, 10, 15, 6, 30));
    expect(p.parsedStatus, RedeemStatus.requested);
  });

  test('payout statuses', () {
    RedeemStatus s(String v) =>
        RewardPayout.fromJson({'status': v}).parsedStatus;
    expect(s('PENDING'), RedeemStatus.requested);
    expect(s('APPROVED'), RedeemStatus.processing);
    expect(s('PAID'), RedeemStatus.paid);
    expect(s('REJECTED'), RedeemStatus.rejected);
    expect(s('CANCELLED'), RedeemStatus.cancelled);
  });

  test('transaction types map to what happened to the balance', () {
    RewardTransaction t(String type, [int coins = 1]) =>
        RewardTransaction.fromJson({'transaction_type': type, 'coins': coins});

    expect(t('EARN_APPROVED_UGC_MEDIA').kind, RewardTxKind.earn);
    expect(t('EARN_APPROVED_UGC_MEDIA').isCredit, isTrue);
    expect(t('WITHDRAWAL_HOLD', 5).kind, RewardTxKind.hold);
    expect(t('WITHDRAWAL_HOLD', 5).isCredit, isFalse);
    expect(t('WITHDRAWAL_RELEASE', 5).isCredit, isTrue);
    expect(t('WITHDRAWAL_PAID', 5).isNeutral, isTrue);
    expect(t('ADMIN_CREDIT', 3).isCredit, isTrue);
    expect(t('ADMIN_DEBIT', 2).isCredit, isFalse);
    expect(t('ADMIN_DEBIT', -2).absCoins, 2);
  });

  group('payout errors come from errors.details', () {
    DioException err(int code, Object? body) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: code,
              data: body),
        );

    test('400 field messages are shown, not "An error occurred."', () {
      final fields = <String, String>{};
      final msg = payoutErrorMessage(
          err(400, {
            'data': null,
            'meta': {},
            'errors': {
              'code': 400,
              'message': 'An error occurred.',
              'details': {
                'coins_requested': ['Insufficient available coins.']
              },
            },
          }),
          fields);
      expect(msg, 'Insufficient available coins.');
      expect(fields['coins_requested'], 'Insufficient available coins.');
    });

    test('429 / 5xx / offline get a clear message', () {
      expect(payoutErrorMessage(err(429, null), {}), contains('ప్రయత్నాలు'));
      expect(payoutErrorMessage(err(503, null), {}), contains('సర్వర్'));
      expect(
          payoutErrorMessage(
              DioException(requestOptions: RequestOptions(path: '/x')), {}),
          contains('ఇంటర్నెట్'));
    });
  });
}
