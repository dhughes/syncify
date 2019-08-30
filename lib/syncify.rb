require "syncify/version"

$LOAD_PATH.unshift(File.dirname(__FILE__))

Dir[File.expand_path('syncify/*.rb', __dir__)].each { |f| require f }
Dir[File.expand_path('syncify/**/*.rb', __dir__)].each { |f| require f }

module Syncify
  class Error < StandardError; end
end
