module Syncify
  module Association
    class StandardAssociation
      attr_accessor :from_class, :to_class, :name, :destination, :traversed

      def initialize(from_class:, association:, destination:)
        @from_class = from_class
        @to_class = association.klass
        @name = association.name
        @destination = destination
        @traversed = false
      end

      def polymorphic?
        false
      end

      def traversed?
        traversed
      end

      def inverse_of?(association)
        if association.polymorphic?
          association.to_classes.include?(from_class) && association.from_class == to_class
        else
          association.to_class == from_class && association.from_class == to_class
        end
      end

      def create_destination(name)
        destination[name] = {}
      end

      def hash
        "#{self.from_class.to_s}#{self.to_class.to_s}#{self.name}".hash
      end

      def eql?(other_association)
        self.from_class == other_association.from_class &&
          self.to_class == other_association.to_class &&
          self.name == other_association.name
      end
    end
  end
end
