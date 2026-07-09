# RakeSlack

Rake tasks for posting CI build outcomes to Slack. A configurable,
first-match-wins routing engine posts build outcomes to Slack channels via
`chat.postMessage`. Channels are addressed by ID so channel renames do not
break routing. Works with any CI system; GitHub Actions gets sensible
defaults out of the box.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rake_slack'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rake_slack

## Usage

Define the notification task in your `Rakefile`, wrapping it in a namespace and
passing the routing table your project needs:

```ruby
require 'rake_slack'

namespace :slack do
  RakeSlack.define_notification_tasks do |t|
    t.bot_token = ENV.fetch('SLACK_BOT_TOKEN', nil)

    # Ordered; first match wins. A rule matches when every key in its `when`
    # equals the corresponding task value (outcome is lowercased first).
    # `when: {}` is the catch-all default.
    t.routing_rules = [
      { when: { type: 'on_hold' },
        channel: 'C038EDCRSQJ', format: :on_hold },
      { when: { actor: 'dependabot[bot]', outcome: 'success' },
        channel: 'C03N711HVDG', format: :success },
      { when: { actor: 'dependabot[bot]' },
        channel: 'C03N711HVDG', format: :failure },
      { when: { outcome: 'success' },
        channel: 'C023XUE76GH', format: :success },
      { when: {},
        channel: 'C01TVGGB0F6', format: :failure }
    ]
  end
end
```

This defines `slack:notify[outcome,type]`. `outcome` is the first bracket
argument (typically the job status); `type` is an optional second argument
(`build` by default, or `on_hold` for the release approval ping).

The ambient build context (`repository`, `workflow`, `branch`, `actor` and
`run_url`) defaults to the GitHub Actions environment variables
(`GITHUB_REPOSITORY`, `GITHUB_WORKFLOW`, `GITHUB_REF_NAME`, `GITHUB_ACTOR`,
`GITHUB_SERVER_URL`/`GITHUB_RUN_ID`), but each is an ordinary task parameter —
on any other CI system, set them explicitly in the configuration block from
that system's environment.

Invoke it from the command line:

```bash
bundle exec rake "slack:notify[success]"          # route on a success outcome
bundle exec rake "slack:notify[failure]"          # route on a failure outcome
bundle exec rake "slack:notify[success,on_hold]"  # release on-hold ping
```

### Routing behaviour

- `cancelled`, `canceled` and `skipped` outcomes are silent (no message is
  posted). Override the set with `t.silent_outcomes`.
- The outcome is lowercased before matching.
- `fail_on_error` defaults to `false`, so Slack API or network failures are
  logged rather than raised — pipelines never break on Slack outages. Set it to
  `true` to fail the task on a delivery error.
- The colour, emoji and status word for each `format` key (`:success`,
  `:failure`, `:on_hold`) can be overridden via `t.formats`.

### GitHub Actions example

Post an outcome from a workflow job (the token comes from a repository secret):

```yaml
- name: Notify Slack
  if: always()
  run: bundle exec rake "slack:notify[${{ job.status }}]"
  env:
    SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

The bot token must be an `xoxb-...` token with the `chat:write` scope, and the
bot must be a member of every target channel.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`bundle exec rake test:unit` to run the tests. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

To release a new version, run `bundle exec rake "version:bump[minor]"` (or
`major`/`patch`/`pre`) and then `bundle exec rake release`, which will create a
git tag for the version, push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/infrablocks/rake_slack. This project is intended to be a
safe, welcoming space for collaboration, and contributors are expected to
adhere to the [Contributor Covenant](http://contributor-covenant.org) code of
conduct.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).
