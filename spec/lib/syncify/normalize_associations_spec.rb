# frozen_string_literal: true

RSpec.describe Syncify::NormalizeAssociations do
  context 'when the association is a symbol' do
    it 'converts it to an array with one hash' do
      association = :example

      normalized_association = Syncify::NormalizeAssociations.run!(association: association)

      expect(normalized_association).to eq([{ example: {} }])
    end
  end

  context 'when the association is an array' do
    context 'when the only element is a symbol' do
      it 'converts it to an array with one hash' do
        association = [:example]

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).to eq([{ example: {} }])
      end
    end

    context 'when there are multiple symbols' do
      it 'converts it to an array with multiple hashes' do
        association = [:example1, :example2]

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).
          to eq(
               [
                 { example1: {} },
                 { example2: {} },
               ]
             )
      end
    end

    context 'when there are combinations of arrays and symbols' do
      it 'converts to an array' do
        association = [:example1, [:example2, :example3]]

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).
          to eq(
               [
                 { example1: {} },
                 { example2: {} },
                 { example3: {} },
               ]
             )
      end
    end

    context 'when the associations are complex' do
      it 'creates a valid array' do
        association = [
          { campaign_group: [
            { campaigns: :campaign_products },
            :campaign_groups_targeting_segments,
            { transactions: %i(coupon issued_by_user) },
          ] },
          { advertiser_profile: [
            :advertiser_profile_sources,
            { ad_configs: :parent },
          ] }
        ]

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).
          to eq(
               [
                 { campaign_group: { campaigns: { campaign_products: {} } } },
                 { campaign_group: { campaign_groups_targeting_segments: {} } },
                 { campaign_group: { transactions: { coupon: {} } } },
                 { campaign_group: { transactions: { issued_by_user: {} } } },
                 { advertiser_profile: { advertiser_profile_sources: {} } },
                 { advertiser_profile: { ad_configs: { parent: {} } } }
               ]
             )
      end
    end
  end

  context 'when the association is a hash' do
    context 'when the hash is empty' do
      it 'returns an empty array' do
        association = {}

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).to eq([])
      end
    end

    context 'when the hash has a single key' do
      it 'returns a normalized array' do
        association = { example: {} }

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).to eq([{ example: {} }])
      end
    end

    context 'when the value is a symbol' do
      it 'returns an array' do
        association = { example: :test }

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).to eq([{ example: { test: {} } }])
      end
    end

    context 'when a hash has multiple keys' do
      it 'returns an array with an element for each key' do
        association = { example1: {}, example2: {} }

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).
          to eq(
               [
                 { example1: {} },
                 { example2: {} },
               ]
             )
      end
    end

    context 'when a hash is nested in a hash' do
      it 'returns a normalized array' do
        association = { example1: { example2: {} } }

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).to eq([{ example1: { example2: {} } }])
      end
    end

    context 'when two hashes are nested in a hash' do
      it 'returns an array with two elements' do
        association = { example1: { example2: {}, example3: {} } }

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).
          to eq(
               [
                 { example1: { example2: {} } },
                 { example1: { example3: {} } }
               ]
             )
      end
    end

    context 'with complex associations' do
      it 'creates a valid array' do
        association = {
          example1: {
            example2: {
              example3: [:example4, :example5]
            },
            example6: {
              example7: {
                example8: :example9
              }
            }
          }
        }

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).
          to eq(
               [
                 { example1: { example2: { example3: { example4: {} } } } },
                 { example1: { example2: { example3: { example5: {} } } } },
                 { example1: { example6: { example7: { example8: { example9: {} } } } } }
               ]
             )
      end
    end
  end

  context 'when the association is not a hash, array, or symbol' do
    it 'returns the association wrapped in an array' do
      association = Syncify::PolymorphicAssociation.new(
        :reference_object,
        AdvertiserProfile => :ad_configs
      )

      normalized_association = Syncify::NormalizeAssociations.run!(association: association)

      expect(normalized_association).to eq([association])
    end

    context 'when the association is complex' do
      it 'returns the association with the polymorphic association in place' do
        association = [
          { campaign_products: [:transactions] },
          Syncify::PolymorphicAssociation.new(
            :reference_object,
            AdvertiserProfile => {},
            Partner::Listing => {}
          )
        ]

        normalized_association = Syncify::NormalizeAssociations.run!(association: association)

        expect(normalized_association).
          to eq([
                  { campaign_products: { transactions: {} } },
                  association[1]
                ])
      end
    end
  end
end
