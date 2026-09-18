import 'package:flutter_test/flutter_test.dart';
import 'package:way2news_clone/models/account_deletion_request.dart';

void main() {
  group('AccountDeletionRequest Model Tests', () {
    test('Correctly parses backend response 201 (pending deletion request)', () {
      final json = {
        "id": "07bfabc8-ac6b-49e3-bbc7-078fd930f720",
        "status": "pending",
        "reason": "privacy",
        "notes": "Remove my data",
        "created_at": "2026-09-18T12:07:41.515918+05:30",
        "reviewed_at": null,
        "executed_at": null
      };

      final req = AccountDeletionRequest.fromJson(json);

      expect(req.id, equals('07bfabc8-ac6b-49e3-bbc7-078fd930f720'));
      expect(req.status, equals('pending'));
      expect(req.isPending, isTrue);
      expect(req.isApproved, isFalse);
      expect(req.isRejected, isFalse);
      expect(req.isCancelled, isFalse);
      expect(req.reason, equals('privacy'));
      expect(req.notes, equals('Remove my data'));
      expect(req.createdAt, isNotNull);
      expect(req.reviewedAt, isNull);
      expect(req.executedAt, isNull);
    });

    test('Correctly parses approved deletion request', () {
      final json = {
        "id": "07bfabc8-ac6b-49e3-bbc7-078fd930f720",
        "status": "approved",
        "reason": "no_longer_used",
        "created_at": "2026-09-18T12:07:41.515918+05:30",
        "reviewed_at": "2026-09-18T12:30:00.000000+05:30",
        "executed_at": "2026-09-18T12:30:05.000000+05:30"
      };

      final req = AccountDeletionRequest.fromJson(json);

      expect(req.isPending, isFalse);
      expect(req.isApproved, isTrue);
      expect(req.isRejected, isFalse);
      expect(req.isCancelled, isFalse);
      expect(req.reviewedAt, isNotNull);
      expect(req.executedAt, isNotNull);
    });

    test('Correctly parses rejected deletion request', () {
      final json = {
        "id": "07bfabc8-ac6b-49e3-bbc7-078fd930f720",
        "status": "rejected",
        "reason": "other",
        "created_at": "2026-09-18T12:07:41.515918+05:30",
        "admin_notes": "Contacted user, resolved."
      };

      final req = AccountDeletionRequest.fromJson(json);

      expect(req.isPending, isFalse);
      expect(req.isApproved, isFalse);
      expect(req.isRejected, isTrue);
      expect(req.isCancelled, isFalse);
      expect(req.adminNotes, equals('Contacted user, resolved.'));
    });

    test('Correctly parses cancelled deletion request', () {
      final json = {
        "id": "07bfabc8-ac6b-49e3-bbc7-078fd930f720",
        "status": "cancelled",
        "reason": "privacy",
        "created_at": "2026-09-18T12:07:41.515918+05:30"
      };

      final req = AccountDeletionRequest.fromJson(json);

      expect(req.isPending, isFalse);
      expect(req.isApproved, isFalse);
      expect(req.isRejected, isFalse);
      expect(req.isCancelled, isTrue);
    });

    test('Provides bilingual reason labels', () {
      expect(
        AccountDeletionRequest.getReasonLabel('privacy', isTelugu: false),
        contains('Privacy'),
      );
      expect(
        AccountDeletionRequest.getReasonLabel('privacy', isTelugu: true),
        contains('గోప్యత'),
      );

      expect(
        AccountDeletionRequest.getReasonLabel('no_longer_used', isTelugu: false),
        contains('no longer use'),
      );
      expect(
        AccountDeletionRequest.getReasonLabel('no_longer_used', isTelugu: true),
        contains('ఉపయోగించడం లేదు'),
      );

      // Unknown code falls back to other
      expect(
        AccountDeletionRequest.getReasonLabel('unknown_xyz', isTelugu: false),
        equals('Other'),
      );
    });

    test('Serializes to JSON accurately', () {
      final req = AccountDeletionRequest(
        id: 'del-123',
        status: 'pending',
        reason: 'privacy',
        notes: 'Please delete my data',
        createdAt: DateTime(2026, 9, 18, 12, 0, 0),
      );

      final map = req.toJson();
      expect(map['id'], equals('del-123'));
      expect(map['status'], equals('pending'));
      expect(map['reason'], equals('privacy'));
      expect(map['notes'], equals('Please delete my data'));
      expect(map['created_at'], isNotNull);
    });
  });
}
