# frozen_string_literal: true

require 'spec_helper'

describe RakeSlack::Tasks::Notify do
  include_context 'rake'

  before do
    stub_output
    stub_env(github_env)
  end

  def define_task(opts = {}, &block)
    opts = { namespace: :slack }.merge(opts)
    namespace opts[:namespace] do
      described_class.define(opts, &block)
    end
  end

  def valid_opts(overrides = {})
    {
      bot_token: 'xoxb-token',
      routing_rules: routing_rules
    }.merge(overrides)
  end

  let(:posted_payloads) { [] }

  it 'adds a notify task in the namespace in which it is created' do
    define_task(valid_opts)

    expect(Rake.application).to(have_task_defined('slack:notify'))
  end

  it 'adds a notify task in the root namespace when none supplied' do
    described_class.define(valid_opts)

    expect(Rake.application).to(have_task_defined('notify'))
  end

  it 'gives the task a description' do
    define_task(valid_opts)

    expect(Rake::Task['slack:notify'].full_comment)
      .to(eq('Post a CI build outcome to Slack.'))
  end

  it 'fails when no bot_token is provided' do
    define_task(routing_rules: routing_rules)

    expect { Rake::Task['slack:notify'].invoke('success') }
      .to(raise_error(RakeFactory::RequiredParameterUnset))
  end

  it 'fails when no routing_rules are provided' do
    define_task(bot_token: 'xoxb-token')

    expect { Rake::Task['slack:notify'].invoke('success') }
      .to(raise_error(RakeFactory::RequiredParameterUnset))
  end

  it 'fails when no outcome argument is supplied' do
    define_task(valid_opts)

    expect { Rake::Task['slack:notify'].invoke }
      .to(raise_error(RakeFactory::RequiredParameterUnset))
  end

  it 'normalises an uppercase silent outcome and stays silent' do
    client = stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('CANCELLED')

    expect(client).not_to(have_received(:post_message))
  end

  it 'stays silent and logs when the outcome is cancelled' do
    client = stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('cancelled')

    expect(client).not_to(have_received(:post_message))
  end

  it 'logs a silent-skip message to stderr when silenced' do
    stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('cancelled')

    expect($stderr)
      .to(have_received(:puts)
        .with(/Outcome 'cancelled' is silent; skipping/))
  end

  it 'stays silent for the US spelling canceled' do
    client = stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('canceled')

    expect(client).not_to(have_received(:post_message))
  end

  it 'stays silent when the outcome is skipped' do
    client = stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('skipped')

    expect(client).not_to(have_received(:post_message))
  end

  it 'honours a custom silent_outcomes set' do
    client = stub_slack_client
    define_task(valid_opts(silent_outcomes: %w[ignored]))

    Rake::Task['slack:notify'].invoke('ignored')

    expect(client).not_to(have_received(:post_message))
  end

  it 'does not silence cancelled when it is not in silent_outcomes' do
    client = stub_slack_client
    define_task(valid_opts(silent_outcomes: %w[ignored]))

    Rake::Task['slack:notify'].invoke('cancelled')

    expect(client).to(have_received(:post_message))
  end

  it 'routes a human success to the builds channel' do
    client = stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('success')

    expected = payload_for(
      channel: 'C023XUE76GH',
      format: format(colour: '#2eb67d', emoji: '✅', word: 'succeeded')
    )
    expect(client).to(have_received(:post_message).with(expected))
  end

  it 'routes a human failure to the team-dev channel' do
    client = stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('failure')

    expected = payload_for(
      channel: 'C01TVGGB0F6',
      format: format(colour: '#e01e5a', emoji: '❌', word: 'failed')
    )
    expect(client).to(have_received(:post_message).with(expected))
  end

  it 'routes a dependabot success to the builds-dependabot channel' do
    client = stub_slack_client
    define_task(valid_opts) { |t| t.actor = 'dependabot[bot]' }

    Rake::Task['slack:notify'].invoke('success')

    expected = payload_for(
      channel: 'C03N711HVDG', actor: 'dependabot[bot]',
      format: format(colour: '#2eb67d', emoji: '✅', word: 'succeeded')
    )
    expect(client).to(have_received(:post_message).with(expected))
  end

  it 'routes a dependabot failure to the builds-dependabot channel' do
    client = stub_slack_client
    define_task(valid_opts) { |t| t.actor = 'dependabot[bot]' }

    Rake::Task['slack:notify'].invoke('failure')

    expected = payload_for(
      channel: 'C03N711HVDG', actor: 'dependabot[bot]',
      format: format(colour: '#e01e5a', emoji: '❌', word: 'failed')
    )
    expect(client).to(have_received(:post_message).with(expected))
  end

  it 'routes an on_hold notification to the release channel' do
    client = stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('success', 'on_hold')

    expected = payload_for(
      channel: 'C038EDCRSQJ',
      format: format(colour: '#ecb22e', emoji: '⏸️',
                     word: 'awaiting approval')
    )
    expect(client).to(have_received(:post_message).with(expected))
  end

  it 'prefers on_hold over the dependabot actor branch' do
    client = stub_slack_client
    define_task(valid_opts) { |t| t.actor = 'dependabot[bot]' }

    Rake::Task['slack:notify'].invoke('success', 'on_hold')

    expected = payload_for(
      channel: 'C038EDCRSQJ', actor: 'dependabot[bot]',
      format: format(colour: '#ecb22e', emoji: '⏸️',
                     word: 'awaiting approval')
    )
    expect(client).to(have_received(:post_message).with(expected))
  end

  it 'does not raise on a delivery failure by default' do
    stub_failing_slack_client
    define_task(valid_opts)

    expect { Rake::Task['slack:notify'].invoke('success') }
      .not_to(raise_error)
  end

  it 'logs a delivery failure to stderr by default' do
    stub_failing_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('success')

    expect($stderr).to(have_received(:puts).with(/boom/))
  end

  it 'raises a delivery failure when fail_on_error is true' do
    stub_failing_slack_client
    define_task(valid_opts(fail_on_error: true))

    expect { Rake::Task['slack:notify'].invoke('success') }
      .to(raise_error(RakeSlack::Exceptions::DeliveryFailed))
  end

  it 'does not raise on a successful post when fail_on_error is true' do
    stub_slack_client
    define_task(valid_opts(fail_on_error: true))

    expect { Rake::Task['slack:notify'].invoke('success') }
      .not_to(raise_error)
  end

  it 'does not raise on a network failure by default' do
    stub_broken_network
    define_task(valid_opts)

    expect { Rake::Task['slack:notify'].invoke('success') }
      .not_to(raise_error)
  end

  it 'logs a network failure to stderr by default' do
    stub_broken_network
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('success')

    expect($stderr).to(have_received(:puts).with(/host down/))
  end

  it 'raises a network failure as a delivery failure ' \
     'when fail_on_error is true' do
    stub_broken_network
    define_task(valid_opts(fail_on_error: true))

    expect { Rake::Task['slack:notify'].invoke('success') }
      .to(raise_error(RakeSlack::Exceptions::DeliveryFailed))
  end

  it 'raises a clear configuration error when no routing rule matches' do
    stub_slack_client
    rules = [rule({ outcome: 'success' }, 'C023XUE76GH', :success)]
    define_task(valid_opts(routing_rules: rules))

    expect { Rake::Task['slack:notify'].invoke('failure') }
      .to(raise_error(RakeSlack::Exceptions::NoMatchingRule,
                      /catch-all.*when: \{\}/m))
  end

  it 'raises a routing miss even when fail_on_error is false' do
    stub_slack_client
    rules = [rule({ outcome: 'success' }, 'C023XUE76GH', :success)]
    define_task(valid_opts(routing_rules: rules, fail_on_error: false))

    expect { Rake::Task['slack:notify'].invoke('failure') }
      .to(raise_error(RakeSlack::Exceptions::NoMatchingRule))
  end

  it 'normalises an uppercase non-silent outcome before routing' do
    client = stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('SUCCESS')

    expected = payload_for(
      channel: 'C023XUE76GH',
      format: format(colour: '#2eb67d', emoji: '✅', word: 'succeeded')
    )
    expect(client).to(have_received(:post_message).with(expected))
  end

  it 'builds the summary from emoji, repository, word and workflow' do
    stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('success')

    expect(posted_payload[:text])
      .to(eq('✅ infrablocks/rake_slack succeeded (Main)'))
  end

  it 'builds the mrkdwn message body per the format' do
    stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('success')

    run_url = 'https://github.com/infrablocks/rake_slack/actions/runs/42'
    expect(attachment_text)
      .to(eq("✅ *<#{run_url}|infrablocks/rake_slack>* succeeded\n" \
             '*Workflow:* Main  *Branch:* `main`  *Actor:* some-human'))
  end

  it 'appends a non-empty context on a new line' do
    stub_slack_client
    define_task(valid_opts) { |t| t.context = 'nightly build' }

    Rake::Task['slack:notify'].invoke('success')

    expect(attachment_text).to(end_with("\nnightly build"))
  end

  it 'omits the context line when context is empty' do
    stub_slack_client
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('success')

    expect(attachment_text).to(end_with('*Actor:* some-human'))
  end

  it 'builds the run_url from the GitHub environment' do
    stub_slack_client
    stub_env(github_env.merge('GITHUB_RUN_ID' => '999'))
    define_task(valid_opts)

    Rake::Task['slack:notify'].invoke('success')

    expect(attachment_text)
      .to(include('https://github.com/infrablocks/rake_slack/actions/runs/999'))
  end

  it 'honours a formats override' do
    stub_slack_client
    formats = {
      success: { colour: '#111111', emoji: '🎉', status_word: 'won' }
    }
    define_task(valid_opts(formats:))

    Rake::Task['slack:notify'].invoke('success')

    expect(posted_payload[:text])
      .to(eq('🎉 infrablocks/rake_slack won (Main)'))
  end

  def stub_output
    %i[print puts].each do |method|
      allow($stdout).to(receive(method))
      allow($stderr).to(receive(method))
    end
  end

  def stub_slack_client
    client = instance_double(RakeSlack::Client)
    allow(client)
      .to(receive(:post_message)) { |payload| posted_payloads << payload }
    allow(RakeSlack::Client).to(receive(:new).and_return(client))
    client
  end

  def stub_failing_slack_client
    client = instance_double(RakeSlack::Client)
    allow(client).to(
      receive(:post_message)
        .and_raise(RakeSlack::Exceptions::DeliveryFailed.new('boom'))
    )
    allow(RakeSlack::Client).to(receive(:new).and_return(client))
    client
  end

  # Uses the real client so raw transport errors exercise the full
  # task-and-client delivery path.
  def stub_broken_network
    socket_error = Excon::Error::Socket.new(SocketError.new('host down'))
    allow(Excon).to(receive(:post).and_raise(socket_error))
  end

  def posted_payload
    posted_payloads.last
  end

  def attachment_text
    posted_payload[:attachments].first[:blocks].first[:text][:text]
  end

  def stub_env(vars)
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:fetch).and_call_original)
    vars.each { |key, value| stub_env_var(key, value) }
  end

  def stub_env_var(key, value)
    allow(ENV).to(receive(:[]).with(key).and_return(value))
    allow(ENV).to(receive(:fetch).with(key, nil).and_return(value))
  end

  def github_env
    {
      'GITHUB_ACTOR' => 'some-human',
      'GITHUB_REPOSITORY' => 'infrablocks/rake_slack',
      'GITHUB_WORKFLOW' => 'Main',
      'GITHUB_REF_NAME' => 'main',
      'GITHUB_SERVER_URL' => 'https://github.com',
      'GITHUB_RUN_ID' => '42'
    }
  end

  def summary_for(format)
    "#{format[:emoji]} infrablocks/rake_slack #{format[:word]} (Main)"
  end

  def message_for(format, actor: 'some-human', context: '')
    run_url = 'https://github.com/infrablocks/rake_slack/actions/runs/42'
    base = "#{format[:emoji]} *<#{run_url}|infrablocks/rake_slack>* " \
           "#{format[:word]}\n" \
           "*Workflow:* Main  *Branch:* `main`  *Actor:* #{actor}"
    context.empty? ? base : "#{base}\n#{context}"
  end

  def payload_for(channel:, format:, actor: 'some-human', context: '')
    {
      channel:,
      text: summary_for(format),
      attachments: [attachment_for(format, actor:, context:)]
    }
  end

  def attachment_for(format, actor:, context:)
    { color: format[:colour],
      blocks: [{ type: 'section',
                 text: { type: 'mrkdwn',
                         text: message_for(format, actor:,
                                                   context:) } }] }
  end

  def format(colour:, emoji:, word:)
    { colour:, emoji:, word: }
  end

  def routing_rules
    dependabot = 'dependabot[bot]'
    [
      rule({ type: 'on_hold' }, 'C038EDCRSQJ', :on_hold),
      rule({ actor: dependabot, outcome: 'success' }, 'C03N711HVDG', :success),
      rule({ actor: dependabot }, 'C03N711HVDG', :failure),
      rule({ outcome: 'success' }, 'C023XUE76GH', :success),
      rule({}, 'C01TVGGB0F6', :failure)
    ]
  end

  def rule(condition, channel, format)
    { when: condition, channel:, format: }
  end
end
