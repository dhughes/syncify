module Syncify
  module Association
    class PolymorphicAssociation
      attr_accessor :from_class, :to_classes, :name, :destinations, :traversed

      def initialize(from_class:, association:, destination:)
        @from_class = from_class
        @to_classes = association.active_record.
          pluck(association.foreign_type).
          compact.
          uniq.
          map(&:constantize)
        @name = association.name
        @destinations = destination[name] = {}
        @traversed = false
      end

      def polymorphic?
        true
      end

      def traversed?
        traversed
      end

      def inverse_of?(association)
        # TODO: implement this for real
        true
      end

      def create_destination(name)
        destinations[name] = {}
      end

      def hash
        "#{self.from_class.to_s}#{self.to_classes.map(&:to_s)}#{self.name}".hash
      end

      def eql?(other_association)
        self.from_class == other_association.from_class &&
          self.to_classes == other_association.to_classes &&
          self.name == other_association.name
      end
    end
  end
end
