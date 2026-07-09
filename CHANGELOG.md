# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com)
and this project adheres to
[Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

## 0.1.0

### Added

- Initial release.
- `RakeSlack.define_notification_tasks` defines a `slack:notify` task that
  posts CI build outcomes to Slack via `chat.postMessage` (build context
  defaults to the GitHub Actions environment variables).
- Data-driven, first-match-wins channel routing via a consumer-supplied
  `routing_rules` table (channels addressed by ID so renames do not break
  routing).
- Silent outcomes (`cancelled`, `canceled`, `skipped`) skip delivery.
- `on_hold` release notifications, dependabot routing, and human
  success/failure routing mirroring the org `slack_notify` composite action.
- `fail_on_error` toggle: delivery failures — including transport errors
  (socket, timeout, connection refused) and non-JSON API responses, all
  wrapped as `RakeSlack::Exceptions::DeliveryFailed` — are logged by default
  and only raised when enabled.
- A routing miss (no rule matches and no catch-all `when: {}` rule) raises
  `RakeSlack::Exceptions::NoMatchingRule` regardless of `fail_on_error`, as
  it is a configuration error.
