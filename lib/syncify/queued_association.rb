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
      return false if class_to_inspect != association.active_record

      if association.polymorphic?
        # interface = association.name
        #
        # referring_classes.find do |referring_class|
        #   referring_class.reflect_on_all_associations.find do |referring_association|
        #     return true if referring_association.options[:as] == interface
        #   end
        # end
        true
      else
        referring_classes.include?(association.klass)
      end
    end
  end
end
