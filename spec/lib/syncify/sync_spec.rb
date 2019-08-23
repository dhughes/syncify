# frozen_string_literal: true

RSpec.describe Syncify::Sync do
  context 'without specifying an association' do
    it 'syncs a single class' do
      remote_campaign = faux_remote do
        create(:campaign)
      end

      Syncify::Sync.run!(klass: Campaign,
                         id: remote_campaign.id,
                         remote_database: :faux_remote_env)

      expect(Campaign.find(remote_campaign.id)).to eq(remote_campaign)
    end
  end

  context 'with an empty association' do
    it 'syncs a single class' do
      remote_campaign = faux_remote do
        create(:campaign)
      end
      associations = {}

      Syncify::Sync.run!(klass: Campaign,
                         id: remote_campaign.id,
                         association: associations,
                         remote_database: :faux_remote_env)

      expect(Campaign.find(remote_campaign.id)).to eq(remote_campaign)
    end
  end

  context 'when syncing a class with a belongs_to association' do
    context 'when using symbol syntax' do
      it 'syncs the class and the associated class' do
        remote_partner, remote_campaign = faux_remote do
          [partner = create(:partner),
           create(:campaign, partner: partner)]
        end
        associations = :partner

        Syncify::Sync.run!(klass: Campaign,
                           id: remote_campaign.id,
                           association: associations,
                           remote_database: :faux_remote_env)

        local_campaign = Campaign.find(remote_campaign.id)
        expect(local_campaign).to eq(remote_campaign)
        expect(local_campaign.partner).to eq(remote_partner)
      end
    end

    context 'when using array syntax' do
      it 'syncs the class and the associated class' do
        remote_partner, remote_campaign = faux_remote do
          [partner = create(:partner),
           create(:campaign, partner: partner)]
        end
        associations = [:partner]

        Syncify::Sync.run!(klass: Campaign,
                           id: remote_campaign.id,
                           association: associations,
                           remote_database: :faux_remote_env)

        local_campaign = Campaign.find(remote_campaign.id)
        expect(local_campaign).to eq(remote_campaign)
        expect(local_campaign.partner).to eq(remote_partner)
      end
    end

    context 'when using hash syntax' do
      it 'syncs the class and the associated class' do
        remote_partner, remote_campaign = faux_remote do
          [partner = create(:partner),
           create(:campaign, partner: partner)]
        end
        associations = {partner: {}}

        Syncify::Sync.run!(klass: Campaign,
                           id: remote_campaign.id,
                           association: associations,
                           remote_database: :faux_remote_env)

        local_campaign = Campaign.find(remote_campaign.id)
        expect(local_campaign).to eq(remote_campaign)
        expect(local_campaign.partner).to eq(remote_partner)
      end
    end
  end

  context 'when syncing a class with a has_many association' do
    it 'syncs the class and all of its configured associations' do
      remote_vertical, remote_partner1, remote_partner2 = faux_remote do
        [vertical = create(:vertical),
         create(:partner, name: 'A', vertical: vertical),
         create(:partner, name: 'B', vertical: vertical)]
      end
      associations = :partners

      Syncify::Sync.run!(klass: Vertical,
                         id: remote_vertical.id,
                         association: associations,
                         remote_database: :faux_remote_env)

      local_vertical = Vertical.find(remote_vertical.id)
      expect(local_vertical).to eq(remote_vertical)
      expect(local_vertical.partners).to eq([remote_partner1, remote_partner2])
    end
  end

  context 'when syncing a combination of different types of associations on a class' do
    it 'syncs the associations as specified' do
      remote_partner = faux_remote do
        create(:partner,
               campaigns: create_list(:campaign, 2),
               vertical: create(:vertical),
               settings: create(:settings))
      end
      associations = [:campaigns, :vertical, :settings]

      Syncify::Sync.run!(klass: Partner,
                         id: remote_partner.id,
                         association: associations,
                         remote_database: :faux_remote_env)

      local_partner = Partner.find(remote_partner.id)

      expect(local_partner).to eq(remote_partner)
      expect(local_partner.campaigns).to eq(remote_partner.campaigns)
      expect(local_partner.vertical).to eq(remote_partner.vertical)
      expect(local_partner.settings).
        to eq(remote_partner.settings)
    end
  end

  context 'when syncing with a polymorphic association' do
    it 'syncs the associations as specified' do
      remote_campaign = faux_remote do
        create(:campaign,
               partner: create(:partner),
               vertical: create(:vertical),
               reference_object: create(:listing))
      end
      associations = [:partner,
                      :vertical,
                      Syncify::PolymorphicAssociation.new(
                        :reference_object,
                        Agent => {},
                        Listing => {}
                      )]

      Syncify::Sync.run!(klass: Campaign,
                         id: remote_campaign.id,
                         association: associations,
                         remote_database: :faux_remote_env)

      local_campaign = Campaign.find(remote_campaign.id)

      expect(local_campaign).to eq(remote_campaign)
      expect(local_campaign.partner).to eq(remote_campaign.partner)
      expect(local_campaign.vertical).to eq(remote_campaign.vertical)
      expect(local_campaign.reference_object).to eq(remote_campaign.reference_object)
    end

    context 'when a polymorphic association has a nil value' do
      it "doesn't track the nil" do
        remote_campaign = faux_remote do
          create(:campaign,
                 partner: create(:partner),
                 vertical: create(:vertical),
                 reference_object: nil)
        end
        associations = [:partner,
                        :vertical,
                        Syncify::PolymorphicAssociation.new(
                          :reference_object,
                          Agent => {},
                          Listing => {}
                        )]

        Syncify::Sync.run!(klass: Campaign,
                           id: remote_campaign.id,
                           association: associations,
                           remote_database: :faux_remote_env)

        local_campaign = Campaign.find(remote_campaign.id)
        expect(local_campaign).to eq(remote_campaign)
        expect(local_campaign.partner).to eq(remote_campaign.partner)
        expect(local_campaign.vertical).to eq(remote_campaign.vertical)
        expect(local_campaign.reference_object).to be_nil
      end
    end
  end

  context 'when syncing a "through" association' do
    it 'correctly syncs the "through" object too' do
      remote_partner = faux_remote do
        product1 = create(:product_a, name: 'thing 1')
        product2 = create(:product_b, name: 'thing 2')
        product3 = create(:product_a, name: 'thing 3')
        product4 = create(:product_b, name: 'thing 4')
        campaign1 = create(:campaign, name: 'campaign 1', products: [product1, product2])
        campaign2 = create(:campaign, name: 'campaign 2', products: [product3, product4])
        create(:partner, campaigns: [campaign1, campaign2])
      end
      associations = :products

      Syncify::Sync.run!(klass: Partner,
                         where: remote_partner.id,
                         association: associations,
                         remote_database: :faux_remote_env)

      expect(Campaign.all.map(&:name)).to eq(['campaign 1', 'campaign 2'])
    end
  end

  context 'when syncing a has and belongs to many' do
    it 'correctly syncs the join table' do
      remote_campaign = faux_remote do
        product1 = create(:product_a, name: 'thing 1')
        product2 = create(:product_b, name: 'thing 2')
        create(:campaign, name: 'campaign 1', products: [product1, product2])
      end
      associations = :products

      Syncify::Sync.run!(klass: Campaign,
                         where: remote_campaign.id,
                         association: associations,
                         remote_database: :faux_remote_env
      )

      campaigns_products = ActiveRecord::Base.connection.execute('select * from campaigns_products')

      expect(campaigns_products.size).to eq(2)
      campaign_ids = campaigns_products.map { |cp| cp['campaign_id'] }
      product_ids = campaigns_products.map { |cp| cp['product_id'] }
      expect(campaign_ids).to eq([remote_campaign.id, remote_campaign.id])
      expect(product_ids).to eq(remote_campaign.products.map(&:id))

    end
  end

  context 'when within a callback' do
    it "does not allow persisting remote objects (you can't update prod)" do
      remote_partner = faux_remote do
        create(:partner, name: 'Blargh')
      end

      Syncify::Sync.run!(klass: Partner,
                         where: remote_partner.id,
                         remote_database: :faux_remote_env,
                         callback:
                           proc do |identified_records|
                             partner = identified_records.first
                             partner.name = 'Ping'
                             partner.save # it would be nice if this somehow raised an error

                             remote_partner2 = faux_remote do
                               Partner.find(remote_partner.id)
                             end

                             expect(remote_partner2).to eq(remote_partner)
                           end
                        )
    end
  end

  context 'when syncing complex associations of various types' do
    it 'does not sync recursively - only the specified associations' do
      remote_campaign = faux_remote do
        vertical1 = create(:vertical, name: 'v1')
        vertical2 = create(:vertical, name: 'v2')
        vertical3 = create(:vertical, name: 'v3')
        create(:partner, vertical: vertical2)
        partner2 = create(:partner, vertical: vertical2)
        create(:partner, vertical: vertical1)
        campaigns = create_list(:campaign, 3, partner: partner2, vertical: vertical3)
        campaigns.last
      end
      associations = [
        :vertical,
        { partner: :vertical }
      ]

      Syncify::Sync.run!(klass: Campaign,
                         id: remote_campaign.id,
                         association: associations,
                         remote_database: :faux_remote_env)

      expect(Vertical.all.size).to eq(2)
      expect(Vertical.all.map(&:name)).to eq(%w(v2 v3))
      expect(Partner.all.size).to eq(1)
      expect(Partner.first.id).to eq(2)
    end

    it 'syncs all the things correctly' do
      remote_campaign = faux_remote do
        vertical = create(:vertical)
        settings = create(:settings)
        partner = create(:partner, vertical: vertical, settings: settings)
        agent = create(:agent)
        listings = create_list(:listing, 5, agent: agent)
        create(:campaign, partner: partner, vertical: vertical, reference_object: listings.last)
      end
      associations = [
        { partner: :settings },
        :vertical,
        Syncify::PolymorphicAssociation.new(
          :reference_object,
          Agent => :listings,
          Listing => { agent: :listings }
        )
      ]

      Syncify::Sync.run!(klass: Campaign,
                         id: remote_campaign.id,
                         association: associations,
                         remote_database: :faux_remote_env)

      expect(Vertical.all.size).to eq(1)
      expect(Settings.all.size).to eq(1)
      expect(Partner.all.size).to eq(1)
      expect(Agent.all.size).to eq(1)
      expect(Listing.all.size).to eq(5)
      expect(Campaign.all.size).to eq(1)
      partner = Partner.first
      expect(partner.vertical).to eq(Vertical.first)
      expect(partner.settings).to eq(Settings.first)
      agent = Agent.first
      expect(agent.listings.size).to eq(5)
      campaign = Campaign.first
      expect(campaign.partner).to eq(partner)
      expect(campaign.vertical).to eq(Vertical.first)
      expect(campaign.reference_object).to eq(agent.listings.last)
    end
  end

  context 'when specifying a callback' do
    it 'the callback can manipulate the identified objects' do
      remote_campaign = faux_remote do
        create(:campaign, vertical: create(:vertical, name: 'bad name'))
      end
      associations = :vertical

      Syncify::Sync.run!(klass: Campaign,
                         id: remote_campaign.id,
                         association: associations,
                         remote_database: :faux_remote_env,
                         callback:
                           proc do |identified_records|
                             expect(identified_records.size).to eq(2)

                             vertical = identified_records.find { |record| record.class == Vertical }
                             vertical.name = 'good name'
                           end
                         )

      expect(Vertical.all.size).to eq(1)
      expect(Vertical.first.name).to eq('good name')
    end
  end

  it 'syncs example orders correctly' do
    remote_campaign = faux_remote do
      product_a = create(:product_a)
      product_b = create(:product_b)
      order_a = create(:order, owner: product_a)
      order_b = create(:order, owner: product_b)
      create(:campaign, products: [product_a, product_b])
    end
    associations = [
      { products: :order }
    ]

    expect do
      Syncify::Sync.run!(klass: Campaign,
                         id: remote_campaign.id,
                         association: associations,
                         remote_database: :faux_remote_env)
    end.to change { Order.all.size }.by(2)
  end

  context 'when a record already exists locally' do
    it 'overwrites the local record' do
      local_partner = create(:partner, id: 999, name: nil)
      remote_partner = faux_remote do
        create(:partner, id: 999, name: 'Wargarble Inc')
      end

      Syncify::Sync.run!(klass: Partner,
                         id: remote_partner.id,
                         remote_database: :faux_remote_env)

      local_partner.reload
      expect(local_partner.name).to eq(remote_partner.name)

    end
  end

  context 'when using a where statement' do
    it 'raises an error if the id argument is also provided' do
      expect do
        Syncify::Sync.run!(klass: Campaign,
                           id: 123,
                           where: { active: true },
                           association: :vertical,
                           remote_database: :faux_remote_env)
      end.
        to raise_error(/Please provide either the id argument or the where argument, but not both./)
    end

    context 'when using activerecord syntax' do
      it 'syncs all matching records' do
        faux_remote do
          create(:partner, name: 'Partner 1', active: true, vertical: create(:vertical, name: 'V1'))
          create(:partner, name: 'Partner 2', active: false, vertical: create(:vertical, name: 'V2'))
          create(:partner, name: 'Partner 3', active: true, vertical: create(:vertical, name: 'V3'))
        end

        expect do
          Syncify::Sync.run!(klass: Partner,
                             where: { active: true },
                             association: :vertical,
                             remote_database: :faux_remote_env)
        end.to change { Partner.all.size }.by(2).
          and change { Vertical.all.size }.by(2)

        expect(Partner.all.map(&:name)).to eq(['Partner 1', 'Partner 3'])
        expect(Vertical.all.map(&:name)).to eq(['V1', 'V3'])
      end
    end

    context 'when using SQL syntax' do
      it 'syncs all matching records' do
        faux_remote do
          create(:partner, name: 'Partner 1', active: true, vertical: create(:vertical, name: 'V1'))
          create(:partner, name: 'Partner 2', active: false, vertical: create(:vertical, name: 'V2'))
          create(:partner, name: 'Partner 3', active: true, vertical: create(:vertical, name: 'V3'))
        end

        expect do
          Syncify::Sync.run!(klass: Partner,
                             where: "partners.active = 't'",
                             association: :vertical,
                             remote_database: :faux_remote_env)
        end.to change { Partner.all.size }.by(2).
          and change { Vertical.all.size }.by(2)

        expect(Partner.all.map(&:name)).to eq(['Partner 1', 'Partner 3'])
        expect(Vertical.all.map(&:name)).to eq(['V1', 'V3'])
      end
    end
  end
end
