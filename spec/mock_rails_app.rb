# frozen_string_literal: true

require 'sqlite3'
require 'active_record'

def setup_active_record
  ActiveRecord::Base.configurations = {
    'default_env' => {
      'adapter' => 'sqlite3',
      'database' => 'spec/default.db'
    },
    'faux_remote_env' => {
      'adapter' => 'sqlite3',
      'database' => 'spec/faux_remote.db'
    }
  }

  ActiveRecord::Base.configurations.keys.each do |config|
    ActiveRecord::Base.establish_connection config.to_sym

    # Set up database tables and columns
    ActiveRecord::Schema.define do
      create_table :campaigns do |t|
        t.references :partner
        t.references :vertical
        t.integer :reference_object_id
        t.string  :reference_object_type
      end
      create_table :partners do |t|
        t.string :name
        t.references :vertical
      end
      create_table :verticals do |t|
        t.string :name
      end
      create_table :settings do |t|
        t.references :partner
      end
      create_table :agents
      create_table :listings do |t|
        t.references :agent
      end
    end
  end
end

# Set up model classes
class Campaign < ActiveRecord::Base
  belongs_to :partner
  belongs_to :vertical
  belongs_to :reference_object, polymorphic: true
end
class Partner < ActiveRecord::Base
  has_many :campaigns
  belongs_to :vertical
  has_one :settings
end
class Vertical < ActiveRecord::Base
  has_many :partners
end
class Settings < ActiveRecord::Base
  belongs_to :partner
end
class Agent < ActiveRecord::Base
  has_many :campaigns, as: :reference_object
  has_many :listings
end
class Listing < ActiveRecord::Base
  has_many :campaigns, as: :reference_object
  belongs_to :agent
end
