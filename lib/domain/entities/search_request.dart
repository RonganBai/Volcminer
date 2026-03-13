class SearchRequest {
  const SearchRequest({
    required this.ips,
    required this.accountUsername,
    required this.accountPassword,
  });

  final List<String> ips;
  final String accountUsername;
  final String accountPassword;
}
