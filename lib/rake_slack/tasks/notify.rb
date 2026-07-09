# frozen_string_literal: true

require 'rake_factory'

require_relative '../client'

module RakeSlack
  module Tasks
    class Notify < RakeFactory::Task
      default_name :notify
      default_description 'Post a CI build outcome to Slack.'
      default_argument_names %i[outcome type]

      parameter :bot_token, required: true
      parameter :routing_rules, required: true

      parameter :silent_outcomes, default: %w[cancelled canceled skipped]
      parameter :fail_on_error, default: false

      parameter :actor, default: RakeFactory::DynamicValue.new {
        ENV.fetch('GITHUB_ACTOR', nil)
      }
      parameter :type, default: 'build'
      parameter :repository, default: RakeFactory::DynamicValue.new {
        ENV.fetch('GITHUB_REPOSITORY', nil)
      }
      parameter :workflow, default: RakeFactory::DynamicValue.new {
        ENV.fetch('GITHUB_WORKFLOW', nil)
      }
      parameter :branch, default: RakeFactory::DynamicValue.new {
        ENV.fetch('GITHUB_REF_NAME', nil)
      }
      parameter :run_url, default: RakeFactory::DynamicValue.new {
        server = ENV.fetch('GITHUB_SERVER_URL', nil)
        repository = ENV.fetch('GITHUB_REPOSITORY', nil)
        run_id = ENV.fetch('GITHUB_RUN_ID', nil)
        "#{server}/#{repository}/actions/runs/#{run_id}"
      }
      parameter :context, default: ''

      parameter :formats, default: {
        success: { colour: '#2eb67d', emoji: '✅', status_word: 'succeeded' },
        failure: { colour: '#e01e5a', emoji: '❌', status_word: 'failed' },
        on_hold: { colour: '#ecb22e', emoji: '⏸️',
                   status_word: 'awaiting approval' }
      }

      action do |t, args|
        outcome = resolve_outcome(args)

        if t.silent_outcomes.include?(outcome)
          log_silent(outcome)
        else
          post(t, outcome, args.type || t.type)
        end
      end

      private

      def resolve_outcome(args)
        outcome = args.outcome
        if outcome.nil? || outcome.to_s.empty?
          raise RakeFactory::RequiredParameterUnset,
                'Required argument outcome unset.'
        end
        outcome.to_s.downcase
      end

      def post(task, outcome, type)
        rule = route(task, outcome, type)
        format = task.formats[rule[:format]]
        payload = build_payload(task, rule[:channel], format, outcome)

        deliver(task, payload)
      end

      def deliver(task, payload)
        RakeSlack::Client.new(task.bot_token).post_message(payload)
      rescue RakeSlack::Exceptions::DeliveryFailed => e
        raise e if task.fail_on_error

        # rubocop:disable Style/StderrPuts
        $stderr.puts(e.message)
        # rubocop:enable Style/StderrPuts
      end

      # A routing miss is a config error: raises regardless of fail_on_error.
      def route(task, outcome, type)
        candidate = { outcome:, actor: task.actor, type: }
        rule = task.routing_rules.find do |r|
          r[:when].all? { |key, value| candidate[key] == value }
        end
        raise RakeSlack::Exceptions::NoMatchingRule, candidate unless rule

        rule
      end

      def build_payload(task, channel, format, _outcome)
        {
          channel:,
          text: summary(task, format),
          attachments: [
            { color: format[:colour],
              blocks: [{ type: 'section',
                         text: { type: 'mrkdwn',
                                 text: message(task, format) } }] }
          ]
        }
      end

      def summary(task, format)
        "#{format[:emoji]} #{task.repository} " \
          "#{format[:status_word]} (#{task.workflow})"
      end

      def message(task, format)
        base =
          "#{format[:emoji]} *<#{task.run_url}|#{task.repository}>* " \
          "#{format[:status_word]}\n" \
          "*Workflow:* #{task.workflow}  *Branch:* `#{task.branch}`  " \
          "*Actor:* #{task.actor}"
        task.context.to_s.empty? ? base : "#{base}\n#{task.context}"
      end

      def log_silent(outcome)
        # rubocop:disable Style/StderrPuts
        $stderr.puts("Outcome '#{outcome}' is silent; skipping " \
                     'Slack notification.')
        # rubocop:enable Style/StderrPuts
      end
    end
  end
end
