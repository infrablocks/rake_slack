# frozen_string_literal: true

require 'rake_slack/version'
require 'rake_slack/exceptions'
require 'rake_slack/client'
require 'rake_slack/tasks'

module RakeSlack
  def self.define_notification_tasks(opts = {}, &)
    RakeSlack::Tasks::Notify.define(opts, &)
  end
end
