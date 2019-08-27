# frozen_string_literal: true

RSpec.describe Syncify::IdentifyAssociations do
  context 'when there are no associations' do
    it 'generates a nil association' do
      ActiveRecord::Schema.define do
        create_table :cats
      end
      class Cat < ActiveRecord::Base;
      end

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
    class SteeringWheel < ActiveRecord::Base;
    end

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
    class Trunk < ActiveRecord::Base;
    end
    class Color < ActiveRecord::Base;
    end

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
    class Engine < ActiveRecord::Base;
    end

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
    class Passenger < ActiveRecord::Base;
    end
    class Pilot < ActiveRecord::Base;
    end

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
    class School < ActiveRecord::Base;
    end
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
    class Category < ActiveRecord::Base;
    end
    class Seller < ActiveRecord::Base;
    end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Ware)

    expect(generated_associations).to eq([:category, :seller])
  end

  it 'returns a hash for a single has many through association' do
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

  it 'returns an array of hashes for multiple has_many through associations' do
    ActiveRecord::Schema.define do
      create_table :buildings
      create_table :apartments do |t|
        t.references :building
      end
      create_table :garages do |t|
        t.references :building
      end
      create_table :tenants do |t|
        t.references :apartment
      end
      create_table :vehicles do |t|
        t.references :garage
      end
    end
    class Building < ActiveRecord::Base
      has_many :apartments
      has_many :tenants, through: :apartments
      has_many :garages
      has_many :vehicles, through: :garages
    end
    class Apartment < ActiveRecord::Base
      belongs_to :building
      has_many :tenants
    end
    class Garage < ActiveRecord::Base
      belongs_to :building
      has_many :vehicles
    end
    class Tenant < ActiveRecord::Base
      belongs_to :apartment
    end
    class Vehicle < ActiveRecord::Base
      belongs_to :garage
    end
    expected_associations = [
      { apartments: :tenants },
      { garages: :vehicles }
    ]

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Building)

    expect(generated_associations).to eq(expected_associations)
  end

  it 'returns a hash for a single has_one through association' do
    ActiveRecord::Schema.define do
      create_table :suppliers
      create_table :accounts do |t|
        t.references :supplier
      end
      create_table :account_histories do |t|
        t.references :account
      end
    end
    # the following was gratuitously stolen from the Rails guides.
    class Supplier < ActiveRecord::Base
      has_one :account
      has_one :account_history, through: :account
    end
    class Account < ActiveRecord::Base
      belongs_to :supplier
      has_one :account_history
    end
    class AccountHistory < ActiveRecord::Base
      belongs_to :account
    end
    expected_associations = { account: :account_history }

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Supplier)

    expect(generated_associations).to eq(expected_associations)
  end

  it 'returns a symbol for a single has_and_belongs_to_many association' do
    ActiveRecord::Schema.define do
      create_table :assemblies
      create_table :parts
      create_table :assemblies_parts, id: false do |t|
        t.belongs_to :assembly
        t.belongs_to :part
      end
    end
    # This example was totally stolen from rails guides.
    class Assembly < ActiveRecord::Base
      has_and_belongs_to_many :parts
    end
    class Part < ActiveRecord::Base
      has_and_belongs_to_many :assemblies
    end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Assembly)

    expect(generated_associations).to eq(:parts)
  end

  context 'with polymorphic associations' do
    it 'does something' do
      ActiveRecord::Schema.define do
        create_table :pictures do |t|
          t.references :imageable, polymorphic: true
        end
        create_table :employees do |t|
          t.references :region
        end
        create_table :gizmos do |t|
          t.references :region
        end
        create_table :regions
      end
      class Picture < ActiveRecord::Base
        belongs_to :imageable, polymorphic: true
      end
      class Employee < ActiveRecord::Base
        has_many :pictures, as: :imageable
        has_one :region
      end
      class Gizmo < ActiveRecord::Base
        has_many :pictures, as: :imageable
      end
      class Region < ActiveRecord::Base;
      end
      Employee.create(pictures: [Picture.new])
      Gizmo.create(pictures: [Picture.new])
      
      generated_associations = Syncify::IdentifyAssociations.run!(klass: Picture)

      expect(generated_associations).to be_a(Syncify::PolymorphicAssociation)
      expect(generated_associations.property).to eq(:imageable)
      expect(generated_associations.associations).to eq(Employee => :region,
                                                        Gizmo => nil)
    end
  end

    # context 'with circular associations' do
    #   it 'does not blow up' do
    #     fail
    #   end
    # end
end
