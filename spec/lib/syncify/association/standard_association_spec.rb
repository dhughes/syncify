# frozen_string_literal: true

RSpec.describe Syncify::Association::PolymorphicAssociation do
  describe '#inverse_of?' do
    context 'when provided with an inverse' do
      context 'when inverse is not polymorphic' do
        it 'indicates it is an inverse' do
          destination = {}
          association = Syncify::Association::StandardAssociation.new(
            from_class: Campaign,
            association: Campaign.reflect_on_association(:partner),
            destination: destination
          )
          inverse = Syncify::Association::StandardAssociation.new(
            from_class: Partner,
            association: Partner.reflect_on_association(:campaigns),
            destination: destination
          )

          expect(association.inverse_of?(inverse)).to eq(true)
        end
      end

      context 'when inverse is polymorphic' do
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

          expect(standard_association.inverse_of?(polymorphic_association)).to eq(true)
        end
      end
    end

    context 'when provided with a non-inverse association' do
      context 'when non-inverse is not polymorphic' do
        it 'returns false' do
          destination = {}
          association = Syncify::Association::StandardAssociation.new(
            from_class: Campaign,
            association: Campaign.reflect_on_association(:partner),
            destination: destination
          )
          inverse = Syncify::Association::StandardAssociation.new(
            from_class: Partner,
            association: Partner.reflect_on_association(:settings),
            destination: destination
          )

          expect(association.inverse_of?(inverse)).to eq(false)
        end

        context 'when inverse is polymorphic' do
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

            expect(standard_association.inverse_of?(polymorphic_association)).to eq(false)
          end
        end
      end
    end
  end
end
