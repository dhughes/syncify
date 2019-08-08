require "bundler/setup"
require 'active_interaction'
require 'pry-byebug'
require 'mock_rails_app'
require 'activerecord-import/base'
require 'activerecord-import/active_record/adapters/sqlite3_adapter'
require 'factory_bot'
require "syncify"

ActiveRecord::Base.logger = Logger.new(STDOUT)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.before(:example) do
    setup_active_record
    ActiveRecord::Base.establish_connection :default_env
  end

  config.after(:example) do
    File.delete('spec/default.db')
    File.delete('spec/faux_remote.db')
  end
end

def faux_remote
  ActiveRecord::Base.establish_connection :faux_remote_env
  yield
ensure
  ActiveRecord::Base.establish_connection :default_env
end
