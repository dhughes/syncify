require "syncify/version"

$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'syncify/identify_associations'
require 'syncify/normalize_associations'
require 'syncify/sync'
require 'syncify/association/polymorphic_association'
require 'syncify/association/standard_association'
require 'syncify/hint/hint'
require 'syncify/hint/basic_hint'

module Syncify
  class Error < StandardError;
  end
end
