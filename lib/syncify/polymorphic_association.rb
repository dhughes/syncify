# frozen_string_literal: true

module Syncify
  class PolymorphicAssociation
    attr_accessor :property
    attr_accessor :associations

    def initialize(property, associations)
      @property = property
      @associations = associations
    end
  end
end
