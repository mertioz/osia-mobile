/// Normalized OSIA pairing-token input shared by manual entry and QR scanning.
final class PairingTokenInput {
  const PairingTokenInput._(this.value, this.issue);

  final String value;
  final PairingTokenIssue? issue;

  bool get isValid => issue == null;
}

enum PairingTokenIssue { empty, malformed, oversized }

// Current PC tokens are 20 lowercase hex characters. Older PC releases used
// 16- and 64-character tokens, so manual pairing keeps accepting both formats.
const Set<int> _acceptedPairingTokenLengths = <int>{16, 20, 64};
const int maxPairingTokenLength = 64;

/// Apply the same whitespace normalization and format validation everywhere.
PairingTokenInput parsePairingToken(String? rawValue) {
  final value = (rawValue ?? '').trim();
  if (value.isEmpty) {
    return const PairingTokenInput._('', PairingTokenIssue.empty);
  }
  if (value.length > maxPairingTokenLength) {
    return PairingTokenInput._(value, PairingTokenIssue.oversized);
  }
  if (!_acceptedPairingTokenLengths.contains(value.length) ||
      !value.codeUnits.every(_isLowercaseHexCodeUnit)) {
    return PairingTokenInput._(value, PairingTokenIssue.malformed);
  }
  return PairingTokenInput._(value, null);
}

bool _isLowercaseHexCodeUnit(int codeUnit) {
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x61 && codeUnit <= 0x66);
}
