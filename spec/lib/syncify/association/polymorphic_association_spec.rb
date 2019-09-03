# frozen_string_literal: true

RSpec.describe Syncify::Association::PolymorphicAssociation do
  describe '#new' do
    it 'identifies the types of associated objects' do
      agent = create(:agent)
      listing = create(:listing)
      create(:campaign, reference_object: agent)
      create(:campaign, reference_object: listing)
      destination = {}
      association = Syncify::Association::PolymorphicAssociation.new(
        from_class: Campaign,
        association: Campaign.reflect_on_association(:reference_object),
        destination: destination
      )

      expect(association.to_classes).to eq([Agent, Listing])
    end

    it 'creates the destinations in the specified destination' do
      agent = create(:agent)
      listing = create(:listing)
      create(:campaign, reference_object: agent)
      create(:campaign, reference_object: listing)
      destination = {}

      association = Syncify::Association::PolymorphicAssociation.new(
        from_class: Campaign,
        association: Campaign.reflect_on_association(:reference_object),
        destination: destination
      )

      expect(destination[:reference_object]).to eq({})
      expect(association.destinations).to be(destination[:reference_object])
    end
  end

  describe '#inverse_of?' do
    context 'when provided with an inverse' do
      it 'indicates it is an inverse' do
        agent = create(:agent)
        listing = create(:listing)
        create(:campaign, reference_object: agent)
        create(:campaign, reference_object: listing)
        destination = {}
        polymorphic_association = Syncify::Association::PolymorphicAssociation.new(
          from_class: Campaign,
          association: Campaign.reflect_on_association(:reference_object),
          destination: destination
        )
        standard_association = Syncify::Association::StandardAssociation.new(
          from_class: Agent,
          association: Agent.reflect_on_association(:campaigns),
          destination: destination
        )

        expect(polymorphic_association.inverse_of?(standard_association)).to eq(true)
      end
    end

    context 'when provided with a non-inverse association' do
      it 'returns false' do
        agent = create(:agent)
        listing = create(:listing)
        create(:campaign, reference_object: agent)
        create(:campaign, reference_object: listing)
        destination = {}
        polymorphic_association = Syncify::Association::PolymorphicAssociation.new(
          from_class: Campaign,
          association: Campaign.reflect_on_association(:reference_object),
          destination: destination
        )
        standard_association = Syncify::Association::StandardAssociation.new(
          from_class: Partner,
          association: Partner.reflect_on_association(:campaigns),
          destination: destination
        )

        expect(polymorphic_association.inverse_of?(standard_association)).to eq(false)
      end
    end
  end

  describe '#eql?' do
    context 'when from, to, and name are the same' do
      it 'returns true' do
        destination = {}
        association1 = Syncify::Association::PolymorphicAssociation.new(
          from_class: Campaign,
          association: Campaign.reflect_on_association(:reference_object),
          destination: destination
        )
        association2 = Syncify::Association::PolymorphicAssociation.new(
          from_class: Campaign,
          association: Campaign.reflect_on_association(:reference_object),
          destination: destination
        )

        expect(association1.eql?(association2)).to eq(true)
      end
    end

    context 'when from, to, and name are not all the same' do
      it 'returns false' do
        destination = {}
        association1 = Syncify::Association::PolymorphicAssociation.new(
          from_class: Campaign,
          association: Campaign.reflect_on_association(:reference_object),
          destination: destination
        )
        association2 = Syncify::Association::PolymorphicAssociation.new(
          from_class: Order,
          association: Order.reflect_on_association(:owner),
          destination: destination
        )

        expect(association1.eql?(association2)).to eq(false)
      end
    end

    context 'when the association being compared is not polymorphic' do
      it 'returns false' do
        destination = {}
        polymorphic_association = Syncify::Association::PolymorphicAssociation.new(
          from_class: Campaign,
          association: Campaign.reflect_on_association(:reference_object),
          destination: destination
        )
        standard_association = Syncify::Association::StandardAssociation.new(
          from_class: Partner,
          association: Partner.reflect_on_association(:campaigns),
          destination: destination
        )

        expect(polymorphic_association.eql?(standard_association)).to eq(false)
      end
    end
  end
end
