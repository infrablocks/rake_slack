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
      assert_ok(execute_post(payload))
    rescue Excon::Error, SystemCallError, JSON::ParserError => e
      raise RakeSlack::Exceptions::DeliveryFailed,
            "Slack chat.postMessage failed: #{e.message}"
    end

    private

    def execute_post(payload)
      Excon.post(URL, headers:, body: JSON.dump(payload))
    end

    def headers
      {
        'Authorization' => "Bearer #{@bot_token}",
        'Content-Type' => 'application/json; charset=utf-8'
      }
    end

    def assert_ok(response)
      unless response.status == 200
        raise RakeSlack::Exceptions::DeliveryFailed,
              "Slack chat.postMessage failed: #{response.status}"
      end

      body = JSON.parse(response.body)
      unless body['ok']
        raise RakeSlack::Exceptions::DeliveryFailed,
              "Slack chat.postMessage failed: #{body['error']}"
      end
      body
    end
  end
end
