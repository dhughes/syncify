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
               partner_automation_setting: create(:partner_automation_setting))
      end
      associations = [:campaigns, :vertical, :partner_automation_setting]

      Syncify::Sync.run!(klass: Partner,
                         id: remote_partner.id,
                         association: associations,
                         remote_database: :faux_remote_env)

      local_partner = Partner.find(remote_partner.id)

      expect(local_partner).to eq(remote_partner)
      expect(local_partner.campaigns).to eq(remote_partner.campaigns)
      expect(local_partner.vertical).to eq(remote_partner.vertical)
      expect(local_partner.partner_automation_setting).
        to eq(remote_partner.partner_automation_setting)
    end
  end
end
