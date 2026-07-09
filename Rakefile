# frozen_string_literal: true

require 'rake_git'
require 'rake_git_crypt'
require 'rake_github'
require 'rake_gpg'
require 'rake_ssh'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'securerandom'
require 'yaml'

require 'rake_slack'

task default: %i[
  library:fix
  test:unit
]

RakeGitCrypt.define_standard_tasks(
  namespace: :git_crypt,

  provision_secrets_task_name: :'secrets:provision',
  destroy_secrets_task_name: :'secrets:destroy',

  install_commit_task_name: :'git:commit',
  uninstall_commit_task_name: :'git:commit',

  gpg_user_key_paths: %w[
    config/gpg
    config/secrets/ci/gpg.public
  ]
)

namespace :git do
  RakeGit.define_commit_task(
    argument_names: [:message]
  ) do |t, args|
    t.message = args.message
  end
end

namespace :encryption do
  namespace :directory do
    desc 'Ensure CI secrets directory exists.'
    task :ensure do
      FileUtils.mkdir_p('config/secrets/ci')
    end
  end

  namespace :passphrase do
    desc 'Generate encryption passphrase for CI GPG key'
    task generate: ['directory:ensure'] do
      File.write(
        'config/secrets/ci/encryption.passphrase',
        SecureRandom.base64(36)
      )
    end
  end
end

namespace :keys do
  namespace :gpg do
    RakeGPG.define_generate_key_task(
      output_directory: 'config/secrets/ci',
      name_prefix: 'gpg',
      owner_name: 'InfraBlocks Maintainers',
      owner_email: 'maintainers@infrablocks.io',
      owner_comment: 'rake_slack CI Key'
    )
  end
end

namespace :secrets do
  namespace :directory do
    desc 'Ensure secrets directory exists and is set up correctly'
    task :ensure do
      FileUtils.mkdir_p('config/secrets')
      unless File.exist?('config/secrets/.unlocked')
        File.write('config/secrets/.unlocked', 'true')
      end
    end
  end

  desc 'Generate all generatable secrets.'
  task generate: %w[
    encryption:passphrase:generate
    keys:gpg:generate
  ]

  desc 'Provision all secrets.'
  task provision: [:generate]

  desc 'Delete all secrets.'
  task :destroy do
    rm_rf 'config/secrets'
  end

  desc 'Rotate all secrets.'
  task rotate: [:'git_crypt:reinstall']
end

RuboCop::RakeTask.new

namespace :library do
  desc 'Run all checks of the library'
  task check: [:rubocop]

  desc 'Attempt to automatically fix issues with the library'
  task fix: [:'rubocop:autocorrect_all']

  desc 'Build the library'
  task :build do
    sh 'gem build rake_slack.gemspec'
  end
end

namespace :test do
  RSpec::Core::RakeTask.new(:unit)
end

# Self-provision this gem's own GitHub secrets and release environment. The
# configuration block reads config/secrets/github/config.yaml lazily (only when
# a github:* task is invoked), so defining these tasks never reads the file.
RakeGithub.define_repository_tasks(
  namespace: :github,
  repository: 'infrablocks/rake_slack'
) do |t|
  github_config =
    YAML.load_file('config/secrets/github/config.yaml')
  rubygems_api_key =
    File.read('config/secrets/rubygems/api_key').chomp

  t.access_token = github_config['github_personal_access_token']
  t.secrets = [
    { name: 'SLACK_BOT_TOKEN',
      value: github_config['slack_bot_token'] },
    { name: 'RUBYGEMS_API_KEY',
      value: rubygems_api_key }
  ]
  t.environments = [{ name: 'release' }]
end

# Dogfood the gem's own Slack notifications. Channels are addressed by ID so
# renames do not break routing. NOTIFY_ACTOR overrides the actor for the test
# workflow because GitHub Actions cannot override GITHUB_ACTOR.
namespace :slack do
  RakeSlack.define_notification_tasks do |t|
    t.bot_token = ENV.fetch('SLACK_BOT_TOKEN', nil)
    notify_actor = ENV.fetch('NOTIFY_ACTOR', nil)
    t.actor = notify_actor if notify_actor
    notify_fail = ENV.fetch('NOTIFY_FAIL_ON_ERROR', nil)
    t.fail_on_error = notify_fail == 'true' unless notify_fail.nil?
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

namespace :version do
  desc 'Bump version for specified type (pre, major, minor, patch)'
  task :bump, [:type] do |_, args|
    bump_version_for(args.type)
  end
end

desc 'Release gem'
task :release do
  sh 'gem release --tag --push'
end

def bump_version_for(version_type)
  sh "gem bump --version #{version_type} " \
     '&& bundle install ' \
     '&& export LAST_MESSAGE="$(git log -1 --pretty=%B)" ' \
     '&& git commit -a --amend -m "${LAST_MESSAGE} [ci skip]"'
end
