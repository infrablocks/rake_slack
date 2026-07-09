# frozen_string_literal: true

require 'json'
require 'excon'

require_relative 'exceptions'

module RakeSlack
  class Client
    URL = 'https://slack.com/api/chat.postMessage'

    def initialize(bot_token)
      @bot_token = bot_token
    end

    def post_message(payload)
      response = Excon.post(
        URL,
        headers: {
          'Authorization' => "Bearer #{@bot_token}",
          'Content-Type' => 'application/json; charset=utf-8'
        },
        body: JSON.dump(payload)
      )
      assert_ok(response)
    end

    private

    def assert_ok(response)
      body = JSON.parse(response.body)
      unless response.status == 200 && body['ok']
        raise RakeSlack::Exceptions::DeliveryFailed,
              'Slack chat.postMessage failed: ' \
              "#{body['error'] || response.status}"
      end
      body
    end
  end
end
