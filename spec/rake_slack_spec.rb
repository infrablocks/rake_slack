# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RakeSlack do
  it 'has a version number' do
    expect(RakeSlack::VERSION).not_to be_nil
  end

  describe 'define_notification_tasks' do
    context 'when instantiating RakeSlack::Tasks::Notify' do
      # rubocop:disable RSpec/MultipleExpectations
      it 'passes the provided opts and block' do
        opts = {
          bot_token: 'xoxb-token'
        }

        block = lambda do |t|
          t.routing_rules = [{ when: {}, channel: 'C1', format: :failure }]
        end

        allow(RakeSlack::Tasks::Notify).to(receive(:define))

        described_class.define_notification_tasks(opts, &block)

        expect(RakeSlack::Tasks::Notify)
          .to(have_received(:define) do |passed_opts, &passed_block|
            expect(passed_opts).to(eq(opts))
            expect(passed_block).to(eq(block))
          end)
      end
      # rubocop:enable RSpec/MultipleExpectations
    end
  end
end
