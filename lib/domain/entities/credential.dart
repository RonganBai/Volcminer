enum CredentialType {
  poolSearchPassword,
  poolSlot1Password,
  poolSlot2Password,
  poolSlot3Password,
  minerAuthPassword,
}

class SecretCredential {
  const SecretCredential(this.value);
  final String value;
}

class MinerCredential {
  const MinerCredential({required this.username, required this.password});

  final String username;
  final String password;
}
