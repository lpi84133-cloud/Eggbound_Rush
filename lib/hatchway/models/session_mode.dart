/// Which experience the coordinator commits this device to.
enum NestRoute {
  /// Content shell (paid-campaign users only, resolved once per install).
  portal,

  /// Native game — the default for anyone reviewers and organic users see.
  native,

  /// First-run: not yet decided (waiting on attribution + config).
  fresh,
}
