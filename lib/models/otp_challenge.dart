enum OtpPurpose { login, registration }

class OtpChallenge {
  const OtpChallenge({required this.identity, required this.purpose});
  final String identity;
  final OtpPurpose purpose;
}
