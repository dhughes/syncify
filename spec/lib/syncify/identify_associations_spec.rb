# frozen_string_literal: true

RSpec.describe Syncify::IdentifyAssociations do
  context 'when there are no associations' do
    it 'generates a nil association' do
      ActiveRecord::Schema.define do
        create_table :cats
      end
      class Cat < ActiveRecord::Base
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
    class SteeringWheel < ActiveRecord::Base
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
    class Trunk < ActiveRecord::Base
    end
    class Color < ActiveRecord::Base
    end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Elephant)

    expect(generated_associations).to eq(%i[trunk color])
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
    class Engine < ActiveRecord::Base
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
    class Passenger < ActiveRecord::Base
    end
    class Pilot < ActiveRecord::Base
    end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Plane)

    expect(generated_associations).to eq(%i[passengers pilots])
  end

  it 'returns a single symbol for a single belongs_to association' do
    ActiveRecord::Schema.define do
      create_table :schools
      create_table :students do |t|
        t.references :schools
      end
    end
    class School < ActiveRecord::Base
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
      create_table :classifications
      create_table :seller
    end
    class Ware < ActiveRecord::Base
      belongs_to :classification
      belongs_to :seller
    end
    class Classification < ActiveRecord::Base
    end
    class Seller < ActiveRecord::Base
    end

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Ware)

    expect(generated_associations).to eq(%i[classification seller])
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
    expected_associations = {
      apartments: :tenants,
      garages: :vehicles
    }

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
    it 'generates a valid polymorphic association description' do
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
      class Region < ActiveRecord::Base
      end
      Employee.create(pictures: [Picture.new])
      Gizmo.create(pictures: [Picture.new])
      expected_associations = {
        imageable: {
          Employee => :region,
          Gizmo => nil
        }
      }

      generated_associations = Syncify::IdentifyAssociations.run!(klass: Picture)

      expect(generated_associations).to eq(expected_associations)
    end

    context 'when there is a nil reference' do
      it 'ignores the nil reference type' do
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
        class Region < ActiveRecord::Base
        end
        Employee.create(pictures: [Picture.new])
        Gizmo.create(pictures: [Picture.new])
        Picture.create
        expected_associations = {
          imageable: {
            Employee => :region,
            Gizmo => nil
          }
        }

        generated_associations = Syncify::IdentifyAssociations.run!(klass: Picture)

        expect(generated_associations).to eq(expected_associations)
      end
    end
  end

  context 'with circular associations' do
    it 'does not get stuck in an infinite loop' do
      ActiveRecord::Schema.define do
        create_table :projects do |t|
          t.references :participant, foreign_key: true
          t.references :group, foreign_key: true
        end
        create_table :participants do |t|
          t.references :group
        end
        create_table :groups
      end

      class Project < ActiveRecord::Base
        belongs_to :participant
        belongs_to :group
      end
      class Participant < ActiveRecord::Base
        has_many :projects
        belongs_to :group
      end
      class Group < ActiveRecord::Base
        has_many :participants
      end

      expected_associations = [
        { participant: :group },
        :group
      ]

      generated_associations = Syncify::IdentifyAssociations.run!(klass: Project)

      expect(generated_associations).to eq(expected_associations)
    end
  end

  context 'when applying hints' do
    context 'when the hint disallows an association' do
      it 'does not include the disallowed association' do
        listing = create(:listing)
        agent = create(:agent, listings: [listing])
        create(:campaign, reference_object: agent)
        create(:campaign, reference_object: listing)
        expected_associatons = [
          :vertical,
          { reference_object: {
            Agent => :listings,
            Listing => nil # this is nil because it would otherwise be :agent and this is an inverse of Agent => :listings
          } },
          { products: :order }
        ]

        generated_associations = Syncify::IdentifyAssociations.run!(
          klass: Campaign,
          hints: [
            Syncify::Hint::BasicHint.new(to_class: Campaign, allowed: false),
            Syncify::Hint::BasicHint.new(to_class: Partner, allowed: false)
          ]
        )

        expect(generated_associations).to eq(expected_associatons)
      end
    end
  end

  it 'can identify complex associations with polymorphic associations' do
    ActiveRecord::Schema.define do
      create_table :customers
      create_table :invoices do |t|
        t.references :customer, foreign_key: true
      end
      create_table :line_items do |t|
        t.references :invoice, foreign_key: true
        t.references :product, polymorphic: true
      end
      create_table :digital_products do |t|
        t.references :category
      end
      create_table :physical_products do |t|
        t.references :distributor
      end
      create_table :categories
      create_table :distributors
    end

    class Customer < ActiveRecord::Base
      has_many :invoices
    end
    class Invoice < ActiveRecord::Base
      belongs_to :customer
      has_many :line_items
    end
    class LineItem < ActiveRecord::Base
      belongs_to :invoice
      belongs_to :product, polymorphic: true
    end
    class DigitalProduct < ActiveRecord::Base
      has_many :line_items, as: :product
      belongs_to :category
    end
    class PhysicalProduct < ActiveRecord::Base
      has_many :line_items, as: :product
      belongs_to :distributor
    end
    class Category < ActiveRecord::Base
      has_many :digital_products
    end
    class Distributor < ActiveRecord::Base
      has_many :physical_products
    end
    ca = Category.create
    di = Distributor.create
    dp = DigitalProduct.create(category: ca)
    pp = PhysicalProduct.create(distributor: di)
    c = Customer.create
    i = Invoice.create(customer: c)
    LineItem.create(invoice: i, product: dp)
    LineItem.create(invoice: i, product: pp)
    expected_associations = {
      invoices: {
        line_items: {
          product: {
            DigitalProduct => :category,
            PhysicalProduct => :distributor
          }
        }
      }
    }

    generated_associations = Syncify::IdentifyAssociations.run!(klass: Customer)

    expect(generated_associations).to eq(expected_associations)
  end

  context 'when an object has an association and is itself associated to from multiple places' do
    it 'traverses all the paths through the object' do
      ActiveRecord::Schema.define do
        create_table :engagements do |t|
          t.references :user
          t.references :affiliate
        end
        create_table :transactions do |t|
          t.references :engagement
          t.references :affiliate
          t.references :issued_by_user, references: :users
        end
        create_table :users do |t|
          t.references :affiliate
        end
        create_table :affiliates
      end

      class Engagement < ActiveRecord::Base
        belongs_to :user
        belongs_to :affiliate
        has_many :transactions
      end
      class Transaction < ActiveRecord::Base
        belongs_to :affiliate
        belongs_to :engagement, optional: true
        belongs_to :issued_by_user, class_name: 'User', optional: true
      end
      class User < ActiveRecord::Base
        belongs_to :affiliate
        has_many :engagements
        has_many :issued_transactions, foreign_key: :issued_by_user_id, class_name: 'Transaction'
      end
      class Affiliate < ActiveRecord::Base
        has_many :transactions
        has_many :users
      end

      affiliate = Affiliate.create
      user1 = User.create(affiliate: affiliate)
      user2 = User.create(affiliate: affiliate)
      user3 = User.create(affiliate: affiliate)
      engagement_transaction1 = Transaction.create(affiliate: affiliate, issued_by_user: user1)
      engagement_transaction2 = Transaction.create(affiliate: affiliate, issued_by_user: user3)
      engagement_transaction3 = Transaction.create(affiliate: affiliate, issued_by_user: user1)
      engagement = Engagement.create(user: user1, affiliate: affiliate, transactions: [engagement_transaction1, engagement_transaction2])

      # expected_associations = [
      #   {
      #     user: [
      #       :affiliate,
      #       issued_transactions: [
      #         :affiliate,
      #         engagements: {}
      #       ]
      #     ]
      #   },
      #   {
      #     affiliate: {
      #       users
      #       transactions: :issued_by_user
      #     }
      #   },
      #   :transactions
      # ]

      # Engagement -> User -> Transactions  ###### don't go to user as it's an inverse in the same branch
      # Engagement -> Affiliate -> Transactions (-> User)
      # Engagement -> Transactions (-> User)
      binding.pry
      generated_associations = Syncify::IdentifyAssociations.run!(klass: Engagement)

    end
  end
end
