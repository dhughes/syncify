# frozen_string_literal: true

RSpec.describe Syncify::Sync do
  it 'does something' do
    remote_campaign = faux_remote do
      create(:campaign)
    end
    associations = {}

    Syncify::Sync.run!(klass: Campaign,
                       id: remote_campaign.id,
                       association: associations,
                       remote_database: :faux_remote_env)

    expect(Campaign.find(1)).to eq(remote_campaign)
  end
end
