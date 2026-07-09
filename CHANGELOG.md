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
  posts GitHub Actions build outcomes to Slack via `chat.postMessage`.
- Data-driven, first-match-wins channel routing via a consumer-supplied
  `routing_rules` table (channels addressed by ID so renames do not break
  routing).
- Silent outcomes (`cancelled`, `canceled`, `skipped`) skip delivery.
- `on_hold` release notifications, dependabot routing, and human
  success/failure routing mirroring the org `slack_notify` composite action.
- `fail_on_error` toggle: delivery failures are logged by default and only
  raised when enabled.
