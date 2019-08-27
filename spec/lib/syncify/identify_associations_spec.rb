# frozen_string_literal: true

RSpec.describe Syncify::IdentifyAssociations do
  context 'when there are no associations' do
    it 'generates a nil association' do
      ActiveRecord::Schema.define do
        create_table :cats
      end
      class Cat < ActiveRecord::Base; end

      generated_associations = Syncify::IdentifyAssociations.run!(klass: Cat)

      expect(generated_associations).to eq(nil)
    end
  end

  it 'returns a single symbol for a single has_one association' do
    ActiveRecord::Schema.define do
      create_table :cars
      create_table :steering_wheels do |t|
        t.references :cars
      end
    end
    class Car < ActiveRecord::Base
      has_one :steering_wheel
    end
    class SteeringWheel < ActiveRecord::Base; end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Car)

    expect(generated_associations).to eq(:steering_wheel)
  end

  it 'returns an array of symbols for multiple has_one associations' do
    ActiveRecord::Schema.define do
      create_table :elephants
      create_table :trunks do |t|
        t.references :elephants
      end
      create_table :colors do |t|
        t.references :elephants
      end
    end
    class Elephant < ActiveRecord::Base
      has_one :trunk
      has_one :color
    end
    class Trunk < ActiveRecord::Base; end
    class Color < ActiveRecord::Base; end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Elephant)

    expect(generated_associations).to eq([:trunk, :color])
  end

  it 'returns a single symbol for a single has_many association' do
    ActiveRecord::Schema.define do
      create_table :trains
      create_table :engines do |t|
        t.references :trains
      end
    end
    class Train < ActiveRecord::Base
      has_many :engines
    end
    class Engine < ActiveRecord::Base; end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Train)

    expect(generated_associations).to eq(:engines)
  end

  it 'returns an array of symbols for multiple has_many associations' do
    ActiveRecord::Schema.define do
      create_table :planes
      create_table :passengers do |t|
        t.references :planes
      end
      create_table :pilots do |t|
        t.references :planes
      end
    end
    class Plane < ActiveRecord::Base
      has_many :passengers
      has_many :pilots
    end
    class Passenger < ActiveRecord::Base; end
    class Pilot < ActiveRecord::Base; end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Plane)

    expect(generated_associations).to eq([:passengers, :pilots])
  end

  it 'returns a single symbol for a single belongs_to association' do
    ActiveRecord::Schema.define do
      create_table :schools
      create_table :students do |t|
        t.references :schools
      end
    end
    class School < ActiveRecord::Base; end
    class Student < ActiveRecord::Base
      belongs_to :school
    end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Student)

    expect(generated_associations).to eq(:school)
  end

  it 'returns an array of symbols for multiple belongs_to associations' do
    ActiveRecord::Schema.define do
      create_table :wares do |t|
        t.references :categories
      end
      create_table :categories
      create_table :seller
    end
    class Ware < ActiveRecord::Base
      belongs_to :category
      belongs_to :seller
    end
    class Category < ActiveRecord::Base; end
    class Seller < ActiveRecord::Base; end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Ware)

    expect(generated_associations).to eq([:category, :seller])
  end

  it 'returns a hash containing a states associated with counties' do
    ActiveRecord::Schema.define do
      create_table :countries
      create_table :states do |t|
        t.references :country
      end
      create_table :counties do |t|
        t.references :state
      end
    end
    class Country < ActiveRecord::Base
      has_many :states
      has_many :counties, through: :states
    end
    class State < ActiveRecord::Base
      belongs_to :country
      has_many :counties
    end
    class County < ActiveRecord::Base
      belongs_to :state
    end
    # The expected associations are a single hash (as opposed to an array) because, in the end, we
    # only care about one association from Country and one from State. In the Country model we
    # disregard :counties because it is a through relationship via states. We know states have
    # counties (otherwise the has_many through wouldn't work), so we can rest assured that we'll
    # get all of the country's counties. In the State class we only care about the :counties
    # association. This is because the belongs_to :countries association relates back to :country,
    # which is where we started from. IE: If parent -> child and child -> parent, Then we disregard
    # the child's parent association.
    expected_associations = { states: :counties }

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Country)

    expect(generated_associations).to eq(expected_associations)
  end

  # it 'returns an array of symbols for multiple has_many through associations' do
  #   fail
  # end
  #
  # it 'returns a single symbol for a single has_one through association' do
  #   fail
  # end
  #
  # it 'returns an array of symbols for multiple has_one through associations' do
  #   fail
  # end
  #
  # it 'returns a single symbol for a single has_and_belongs_to_many association' do
  #   fail
  # end
  #
  # it 'returns an array of symbols for multiple has_and_belongs_to_many associations' do
  #   fail
  # end
end
