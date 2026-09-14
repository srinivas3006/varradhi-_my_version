import 'package:flutter_test/flutter_test.dart';
import 'support/integration_contract_cases.dart';

void main() {
  for (final entry in integrationContractCases().entries) {
    test(entry.key, entry.value);
  }
}
