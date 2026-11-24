import 'dart:io' show stdout;

import '../test/support/integration_contract_cases.dart';

void main() {
  final cases = integrationContractCases();
  for (final entry in cases.entries) {
    entry.value();
    stdout.writeln('PASS ${entry.key}');
  }
  stdout.writeln('${cases.length} integration contract checks passed.');
}
