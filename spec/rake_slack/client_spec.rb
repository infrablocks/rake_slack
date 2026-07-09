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

  it 'wraps a transport error as a delivery failure' do
    socket_error = Excon::Error::Socket.new(SocketError.new('host down'))
    allow(Excon).to(receive(:post).and_raise(socket_error))

    expect { described_class.new('xoxb-token').post_message({}) }
      .to(raise_error(RakeSlack::Exceptions::DeliveryFailed, /host down/))
  end

  it 'wraps a timeout error as a delivery failure' do
    allow(Excon).to(receive(:post).and_raise(Excon::Error::Timeout))

    expect { described_class.new('xoxb-token').post_message({}) }
      .to(raise_error(RakeSlack::Exceptions::DeliveryFailed))
  end

  it 'wraps a low-level system call error as a delivery failure' do
    allow(Excon).to(receive(:post).and_raise(Errno::ECONNREFUSED))

    expect { described_class.new('xoxb-token').post_message({}) }
      .to(raise_error(RakeSlack::Exceptions::DeliveryFailed))
  end

  it 'raises a delivery failure for a non-JSON error body' do
    stub_raw_response(status: 502, body: '<html>Bad Gateway</html>')

    expect { described_class.new('xoxb-token').post_message({}) }
      .to(raise_error(RakeSlack::Exceptions::DeliveryFailed, /502/))
  end

  it 'wraps a non-JSON success body as a delivery failure' do
    stub_raw_response(status: 200, body: 'not json')

    expect { described_class.new('xoxb-token').post_message({}) }
      .to(raise_error(RakeSlack::Exceptions::DeliveryFailed))
  end

  def stub_raw_response(status:, body:)
    response = instance_double(Excon::Response, status:, body:)
    allow(Excon).to(receive(:post).and_return(response))
    response
  end
end
