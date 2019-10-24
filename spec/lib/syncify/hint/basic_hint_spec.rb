# frozen_string_literal: true

RSpec.describe Syncify::Hint::BasicHint do
  describe '#applicable?' do
    context 'when no specifics defined' do
      it 'returns true' do
        hint = Syncify::Hint::BasicHint.new(allowed: true)
        association = Agent.reflect_on_association(:campaigns)

        expect(hint.applicable?(association)).to eq(true)
      end
    end

    context 'when applied to associations from a specific class' do
      context 'when a single class' do
        it 'indicates applicability based only on class name' do
          hint = Syncify::Hint::BasicHint.new(from_class: Campaign, allowed: true)

          Campaign.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(true)
          end
          Partner.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(false)
          end
        end
      end

      context 'when an array of classes' do
        it 'indicates applicability based only on class name' do
          hint = Syncify::Hint::BasicHint.new(from_class: [Campaign, Partner], allowed: true)

          Campaign.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(true)
          end
          Partner.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(true)
          end
          Vertical.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(false)
          end
        end
      end
    end

    context 'when applied to associations with specific names' do
      context 'when naming a single association' do
        it 'indicates applicability based only on association name' do
          hint = Syncify::Hint::BasicHint.new(association: [:campaigns], allowed: true)
          association1 = Agent.reflect_on_association(:campaigns)
          association2 = Listing.reflect_on_association(:campaigns)
          association3 = Listing.reflect_on_association(:agent)

          expect(hint.applicable?(association1)).to eq(true)
          expect(hint.applicable?(association2)).to eq(true)
          expect(hint.applicable?(association3)).to eq(false)
        end
      end

      context 'when naming an array of associations' do
        it 'indicates applicability based only on association name' do
          hint = Syncify::Hint::BasicHint.new(association: [:campaigns, :products], allowed: true)
          association1 = Agent.reflect_on_association(:campaigns)
          association2 = Listing.reflect_on_association(:campaigns)
          association3 = Partner.reflect_on_association(:products)
          association4 = Partner.reflect_on_association(:vertical)

          expect(hint.applicable?(association1)).to eq(true)
          expect(hint.applicable?(association2)).to eq(true)
          expect(hint.applicable?(association3)).to eq(true)
          expect(hint.applicable?(association4)).to eq(false)
        end
      end

      context 'when specifying a regex' do
        it 'indicates applicability only for associations with names that match the regex' do
          hint = Syncify::Hint::BasicHint.new(association: /partner/, allowed: false)
          association1 = Campaign.reflect_on_association(:partner)
          association2 = Vertical.reflect_on_association(:partners)
          association3 = Agent.reflect_on_association(:listings)

          expect(hint.applicable?(association1)).to eq(true)
          expect(hint.applicable?(association2)).to eq(true)
          expect(hint.applicable?(association3)).to eq(false)
        end
      end
    end

    context 'when applied to associations to a specific class' do
      context 'when a single class' do
        it 'indicates applicability only for associations to the specific class' do
          hint = Syncify::Hint::BasicHint.new(to_class: Partner, allowed: false)
          association1 = Vertical.reflect_on_association(:partners)
          association2 = Campaign.reflect_on_association(:partner)
          association3 = Campaign.reflect_on_association(:vertical)

          expect(hint.applicable?(association1)).to eq(true)
          expect(hint.applicable?(association2)).to eq(true)
          expect(hint.applicable?(association3)).to eq(false)
        end
      end

      context 'when an array of classes' do
        it 'indicates applicability only for associations to the specified classes' do
          hint = Syncify::Hint::BasicHint.new(to_class: [Partner, Campaign], allowed: false)
          association1 = Vertical.reflect_on_association(:partners)
          association2 = Campaign.reflect_on_association(:partner)
          association3 = Campaign.reflect_on_association(:vertical)
          association4 = Partner.reflect_on_association(:campaigns)

          expect(hint.applicable?(association1)).to eq(true)
          expect(hint.applicable?(association2)).to eq(true)
          expect(hint.applicable?(association3)).to eq(false)
          expect(hint.applicable?(association4)).to eq(true)
        end

        context 'when association being tested is polymorphic' do
          it 'does something' do
            hint = Syncify::Hint::BasicHint.new(to_class: [Agent, Vertical], allowed: false)
            association1 = Campaign.reflect_on_association(:reference_object)
            association2 = Order.reflect_on_association(:owner)
            agent = create(:agent)
            listing = create(:listing, agent: agent)
            campaign1 = create(:campaign, reference_object: listing)
            campaign2 = create(:campaign, reference_object: agent)
            order = create(:order)
            product1 = create(:product_a, order: order)
            product2 = create(:product_b, order: order)

            expect(hint.applicable?(association1)).to eq(true)
            expect(hint.applicable?(association2)).to eq(false)
          end
        end
      end
    end

    context 'when applied to a combination of attributes' do
      context 'when combining from_class and associations' do
        it 'indicates applicability accordingly' do
          hint = Syncify::Hint::BasicHint.new(from_class: Campaign, association: [:partner, :vertical], allowed: false)
          association1 = Campaign.reflect_on_association(:partner)
          association2 = Campaign.reflect_on_association(:vertical)
          association3 = Campaign.reflect_on_association(:products)
          association4 = Partner.reflect_on_association(:vertical)
          association5 = Vertical.reflect_on_association(:partners)

          expect(hint.applicable?(association1)).to eq(true)
          expect(hint.applicable?(association2)).to eq(true)
          expect(hint.applicable?(association3)).to eq(false)
          expect(hint.applicable?(association4)).to eq(false)
          expect(hint.applicable?(association5)).to eq(false)
        end
      end

      context 'when combining associations and to_class' do
        it 'indicates applicability accordingly' do
          hint = Syncify::Hint::BasicHint.new(association: [:partner, :partners], to_class: Partner, allowed: false)
          association1 = Campaign.reflect_on_association(:partner)
          association2 = Vertical.reflect_on_association(:partners)
          association3 = Agent.reflect_on_association(:listings)

          expect(hint.applicable?(association1)).to eq(true)
          expect(hint.applicable?(association2)).to eq(true)
          expect(hint.applicable?(association3)).to eq(false)
        end
      end

      context 'when specifying a polymorphic association and a to_class' do

      end

      context 'when combining all three' do
        it 'indicates applicability accordingly' do
          hint = Syncify::Hint::BasicHint.new(from_class: Campaign, association: :reference_object, to_class: Agent, allowed: false)
          association1 = Campaign.reflect_on_association(:reference_object)
          association2 = Campaign.reflect_on_association(:partner)
          association3 = Agent.reflect_on_association(:campaigns)
          listing = create(:listing)
          agent = create(:agent, listings: [listing])
          campaign1 = create(:campaign, reference_object: agent)
          campaign2 = create(:campaign, reference_object: listing)

          expect(hint.applicable?(association1)).to eq(true)
          expect(hint.applicable?(association2)).to eq(false)
          expect(hint.applicable?(association3)).to eq(false)
        end
      end

    end
  end

  describe '#allowed?' do
    context 'when applicable and not allowed' do
      context 'when no specifics have been defined' do
        it 'is not allowed' do
          hint = Syncify::Hint::BasicHint.new(allowed: false)

          Campaign.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(true)
            expect(hint.allowed?).to eq(false)
          end

          Partner.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(true)
            expect(hint.allowed?).to eq(false)
          end
        end
      end

      context 'when only ignoring associations from a specific class' do
        it "ignores all of the specified class's associations" do
          hint = Syncify::Hint::BasicHint.new(from_class: Campaign, allowed: false)

          Campaign.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(true)
            expect(hint.allowed?).to eq(false)
          end
        end
      end

      context 'when only ignoring associations with specific names' do
        context 'when naming a single association' do
          it 'ignores associations with the specified name, regardless of class' do
            hint = Syncify::Hint::BasicHint.new(association: [:campaigns], allowed: false)
            association1 = Agent.reflect_on_association(:campaigns)
            association2 = Listing.reflect_on_association(:campaigns)

            expect(hint.applicable?(association1)).to eq(true)
            expect(hint.allowed?).to eq(false)
            expect(hint.applicable?(association2)).to eq(true)
            expect(hint.allowed?).to eq(false)
          end
        end

        context 'when naming an array of associations' do
          it 'ignores associations with the specified names, regardless of class' do
            hint = Syncify::Hint::BasicHint.new(association: [:campaigns, :products], allowed: false)
            association1 = Agent.reflect_on_association(:campaigns)
            association2 = Listing.reflect_on_association(:campaigns)
            association3 = Partner.reflect_on_association(:products)

            expect(hint.applicable?(association1)).to eq(true)
            expect(hint.allowed?).to eq(false)
            expect(hint.applicable?(association2)).to eq(true)
            expect(hint.allowed?).to eq(false)
            expect(hint.applicable?(association3)).to eq(true)
            expect(hint.allowed?).to eq(false)
          end
        end

        context 'when specifying a regex' do
          it 'ignores associations with names that match the regex, regardless of class' do
            hint = Syncify::Hint::BasicHint.new(association: /partner/, allowed: false)
            association1 = Campaign.reflect_on_association(:partner)
            association2 = Vertical.reflect_on_association(:partners)

            expect(hint.applicable?(association1)).to eq(true)
            expect(hint.allowed?).to eq(false)
            expect(hint.applicable?(association2)).to eq(true)
            expect(hint.allowed?).to eq(false)
          end
        end
      end

      context 'when only ignoring associations to a specific class' do
        it 'ignores associations to the specific class' do
          hint = Syncify::Hint::BasicHint.new(to_class: Partner, allowed: false)
          association1 = Vertical.reflect_on_association(:partners)
          association2 = Campaign.reflect_on_association(:partner)

          expect(hint.applicable?(association1)).to eq(true)
          expect(hint.allowed?).to eq(false)
          expect(hint.applicable?(association2)).to eq(true)
          expect(hint.allowed?).to eq(false)
        end
      end


    end

    context 'when applicable and allowed' do
      context 'when no specifics have been defined' do
        it 'is allowed' do
          hint = Syncify::Hint::BasicHint.new(allowed: true)

          Campaign.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(true)
            expect(hint.allowed?).to eq(true)
          end

          Partner.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(true)
            expect(hint.allowed?).to eq(true)
          end
        end
      end

      context 'when only ignoring associations from a specific class' do
        it "allows all of the specified class's associations" do
          hint = Syncify::Hint::BasicHint.new(from_class: Campaign, allowed: true)

          Campaign.reflect_on_all_associations.each do |association|
            expect(hint.applicable?(association)).to eq(true)
            expect(hint.allowed?).to eq(true)
          end
        end
      end

      context 'when only ignoring associations with specific names' do
        context 'when naming a single association' do
          it 'allows associations with the specified name, regardless of class' do
            hint = Syncify::Hint::BasicHint.new(association: [:campaigns], allowed: true)
            association1 = Agent.reflect_on_association(:campaigns)
            association2 = Listing.reflect_on_association(:campaigns)

            expect(hint.applicable?(association1)).to eq(true)
            expect(hint.allowed?).to eq(true)
            expect(hint.applicable?(association2)).to eq(true)
            expect(hint.allowed?).to eq(true)
          end
        end

        context 'when naming an array of associations' do
          it 'allows associations with the specified names, regardless of class' do
            hint = Syncify::Hint::BasicHint.new(association: [:campaigns, :products], allowed: true)
            association1 = Agent.reflect_on_association(:campaigns)
            association2 = Listing.reflect_on_association(:campaigns)
            association3 = Partner.reflect_on_association(:products)

            expect(hint.applicable?(association1)).to eq(true)
            expect(hint.allowed?).to eq(true)
            expect(hint.applicable?(association2)).to eq(true)
            expect(hint.allowed?).to eq(true)
            expect(hint.applicable?(association3)).to eq(true)
            expect(hint.allowed?).to eq(true)
          end
        end

        context 'when specifying a regex' do
          it 'allows associations with names that match the regex, regardless of class' do
            hint = Syncify::Hint::BasicHint.new(association: /partner/, allowed: true)
            association1 = Campaign.reflect_on_association(:partner)
            association2 = Vertical.reflect_on_association(:partners)

            expect(hint.applicable?(association1)).to eq(true)
            expect(hint.allowed?).to eq(true)
            expect(hint.applicable?(association2)).to eq(true)
            expect(hint.allowed?).to eq(true)
          end
        end
      end

      context 'when only ignoring associations to a specific class' do
        it 'allows associations to the specific class' do
          hint = Syncify::Hint::BasicHint.new(to_class: Partner, allowed: true)
          association1 = Vertical.reflect_on_association(:partners)
          association2 = Campaign.reflect_on_association(:partner)

          expect(hint.applicable?(association1)).to eq(true)
          expect(hint.allowed?).to eq(true)
          expect(hint.applicable?(association2)).to eq(true)
          expect(hint.allowed?).to eq(true)
        end
      end
    end
  end
end
