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
        t.string :name
        t.references :partner, foreign_key: true
        t.references :vertical, foreign_key: true
        t.integer :reference_object_id
        t.string  :reference_object_type
        t.timestamps null: false
      end
      create_join_table :campaigns, :products
      create_table :products do |t|
        t.string :type
        t.string :name
        t.references :campaign, foreign_key: true
        t.timestamps null: false
      end
      create_table :orders do |t|
        t.references :owner, polymorphic: true
        t.timestamps null: false
      end
      create_table :partners do |t|
        t.string :name
        t.boolean :active
        t.references :vertical, foreign_key: true
        t.timestamps null: false
      end
      create_table :verticals do |t|
        t.string :name
        t.timestamps null: false
      end
      create_table :settings do |t|
        t.references :partner, foreign_key: true
        t.timestamps null: false
      end
      create_table :agents
      create_table :listings do |t|
        t.references :agent, foreign_key: true
        t.timestamps null: false
      end
    end
  end
end

# Set up model classes
class Campaign < ActiveRecord::Base
  belongs_to :partner
  belongs_to :vertical
  belongs_to :reference_object, polymorphic: true
  has_and_belongs_to_many :products
end
class Product < ActiveRecord::Base
  has_and_belongs_to_many :campaign
  has_one :order, -> { where 'owner_id IS NOT NULL' }, as: :owner
end
class ProductA < Product; end
class ProductB < Product; end
class Order < ActiveRecord::Base
  belongs_to :owner, polymorphic: true
end
class Partner < ActiveRecord::Base
  has_many :campaigns
  belongs_to :vertical
  has_one :settings
  has_many :products, through: :campaigns
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
