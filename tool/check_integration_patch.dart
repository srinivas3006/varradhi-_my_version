import '../test/support/integration_contract_cases.dart';

void main() {
  final cases = integrationContractCases();
  for (final entry in cases.entries) {
    entry.value();
    print('PASS ${entry.key}');
  }
  print('${cases.length} integration contract checks passed.');
}
