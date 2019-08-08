# frozen_string_literal: true

RSpec.describe Syncify::Sync do
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
end
