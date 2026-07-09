# frozen_string_literal: true

module RakeSlack
  module Exceptions
    class NoMatchingRule < StandardError
      def initialize(candidate)
        super(
          "No routing rule matches #{candidate.inspect}. Add a catch-all " \
          'rule (when: {}) to the end of routing_rules.'
        )
      end
    end
  end
end
