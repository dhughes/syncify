module Syncify
  module Association
    class PolymorphicAssociation
      attr_accessor :from_class, :to_classes, :name, :destinations, :traversed

      def initialize(from_class:, association:, destination:)
        @from_class = from_class
        # TODO: is there a way to cache this so it doesn't get run over and over?
        # TODO: here's a problem: we need to run this association check on the _remote_ DB. Otherwise, we might not have all the possible associations locally.
        @to_classes = association.active_record.
          where("#{association.foreign_type} != ''").
          distinct.
          pluck(association.foreign_type).
          uniq.
          compact.
          map(&:constantize)
        @name = association.name
        @destinations = destination[name] = {}
        @traversed = false
      # rescue StandardError => e
      #   binding.pry
      end

      def polymorphic?
        true
      end

      def traversed?
        traversed
      end

      def inverse_of?(association)
        if association.polymorphic?
          # TODO: I'm not 100% sure this is correct. I need to write a test.
          association.to_classes.include?(from_class) &&
            to_classes.include?(association.from_class)
        else
          from_class == association.to_class &&
            to_classes.include?(association.from_class)
        end
      end

      def create_destination(name)
        destinations[name] = {}
      end

      def hash
        "#{self.from_class.to_s}#{self.to_classes.map(&:to_s)}#{self.name}".hash
      end

      def eql?(other_association)
        return false unless other_association.is_a? PolymorphicAssociation
        self.from_class == other_association.from_class &&
          self.to_classes == other_association.to_classes &&
          self.name == other_association.name
      end
    end
  end
end
