module Syncify
  module Association
    class StandardAssociation
      attr_accessor :from_class, :to_class, :name, :destination, :traversed

      def initialize(from_class:, to_class:, name:, destination:)
        @from_class = from_class
        @to_class = to_class
        @name = name
        @destination = destination
        @traversed = false
      end

      def traversed?
        traversed
      end

      def equal?(other_association)
        self.from_class == other_association.from_class &&
          self.to_class == other_association.to_class &&
          self.name == other_association.name
      end
    end
  end
end
