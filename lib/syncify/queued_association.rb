module Syncify
  class QueuedAssociation
    attr_accessor :class_to_inspect, :destination, :referring_classes

    def initialize(class_to_inspect:, destination:)
      @class_to_inspect = class_to_inspect
      @destination = destination
      @referring_classes = []
    end

    def for_class?(clazz)
      class_to_inspect == clazz
    end

    def reciprocal?(association)
      class_to_inspect == association.active_record &&
        referring_classes.include?(association.klass)
    end
  end
end
