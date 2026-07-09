# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe RakeSlack::Client do
  def stub_response(status:, body:)
    response = instance_double(Excon::Response, status:, body: JSON.dump(body))
    allow(Excon).to(receive(:post).and_return(response))
    response
  end

  it 'posts the payload as JSON to chat.postMessage' do
    stub_response(status: 200, body: { ok: true })

    described_class.new('xoxb-token').post_message({ channel: 'C1' })

    expect(Excon).to(
      have_received(:post).with(
        'https://slack.com/api/chat.postMessage',
        hash_including(
          headers: hash_including(
            'Authorization' => 'Bearer xoxb-token',
            'Content-Type' => 'application/json; charset=utf-8'
          ),
          body: JSON.dump({ channel: 'C1' })
        )
      )
    )
  end

  it 'returns the parsed body on a successful response' do
    stub_response(status: 200, body: { ok: true, channel: 'C1' })

    result = described_class.new('xoxb-token').post_message({})

    expect(result).to(eq({ 'ok' => true, 'channel' => 'C1' }))
  end

  it 'raises when the response body reports ok false' do
    stub_response(status: 200, body: { ok: false, error: 'channel_not_found' })

    expect { described_class.new('xoxb-token').post_message({}) }
      .to(raise_error(RakeSlack::Exceptions::DeliveryFailed,
                      /channel_not_found/))
  end

  it 'raises when the HTTP status is not 200' do
    stub_response(status: 500, body: { ok: false })

    expect { described_class.new('xoxb-token').post_message({}) }
      .to(raise_error(RakeSlack::Exceptions::DeliveryFailed, /500/))
  end
end
