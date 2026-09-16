import 'package:flutter/material.dart';
import '../../presentation/theme/admin_colors.dart';

enum AdminUgcStatus { pending, review, flagged, approved, rejected }

extension AdminUgcStatusX on AdminUgcStatus {
  static AdminUgcStatus fromWire(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'REVIEW':
        return AdminUgcStatus.review;
      case 'FLAGGED':
        return AdminUgcStatus.flagged;
      case 'APPROVED':
        return AdminUgcStatus.approved;
      case 'REJECTED':
        return AdminUgcStatus.rejected;
      case 'PENDING':
      default:
        return AdminUgcStatus.pending;
    }
  }

  String get wireValue {
    switch (this) {
      case AdminUgcStatus.pending:
        return 'PENDING';
      case AdminUgcStatus.review:
        return 'REVIEW';
      case AdminUgcStatus.flagged:
        return 'FLAGGED';
      case AdminUgcStatus.approved:
        return 'APPROVED';
      case AdminUgcStatus.rejected:
        return 'REJECTED';
    }
  }

  String get label => teluguLabel;

  String get teluguLabel {
    switch (this) {
      case AdminUgcStatus.pending:
        return 'పెండింగ్';
      case AdminUgcStatus.review:
        return 'సమీక్షలో ఉంది';
      case AdminUgcStatus.flagged:
        return 'ఫ్లాగ్ చేయబడింది';
      case AdminUgcStatus.approved:
        return 'ఆమోదించబడింది';
      case AdminUgcStatus.rejected:
        return 'తిరస్కరించబడింది';
    }
  }

  /// True for statuses whose quick-action row is "flag + Reject + Approve".
  bool get isPendingLike => this == AdminUgcStatus.pending || this == AdminUgcStatus.review;

  Color color(bool isDark) {
    switch (this) {
      case AdminUgcStatus.pending:
      case AdminUgcStatus.review:
        return AdminColors.warning;
      case AdminUgcStatus.flagged:
      case AdminUgcStatus.rejected:
        return AdminColors.error;
      case AdminUgcStatus.approved:
        return AdminColors.success;
    }
  }
}

enum AdminTrustLevel { newUser, trustedReporter, adminReporter }

extension AdminTrustLevelX on AdminTrustLevel {
  static AdminTrustLevel fromWire(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'TRUSTED_REPORTER':
        return AdminTrustLevel.trustedReporter;
      case 'ADMIN_REPORTER':
        return AdminTrustLevel.adminReporter;
      case 'NEW_USER':
      default:
        return AdminTrustLevel.newUser;
    }
  }

  String get wireValue {
    switch (this) {
      case AdminTrustLevel.newUser:
        return 'NEW_USER';
      case AdminTrustLevel.trustedReporter:
        return 'TRUSTED_REPORTER';
      case AdminTrustLevel.adminReporter:
        return 'ADMIN_REPORTER';
    }
  }

  String get label => teluguLabel;

  String get teluguLabel {
    switch (this) {
      case AdminTrustLevel.newUser:
        return 'కొత్త రిపోర్టర్';
      case AdminTrustLevel.trustedReporter:
        return 'విశ్వసనీయ రిపోర్టర్';
      case AdminTrustLevel.adminReporter:
        return 'అడ్మిన్ రిపోర్టర్';
    }
  }
}
