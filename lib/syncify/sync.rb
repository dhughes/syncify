# frozen_string_literal: true

module Syncify
  class Sync < ActiveInteraction::Base
    object :klass, class: Class
    integer :id, default: nil
    object :where, class: Object, default: nil
    object :association, class: Object, default: []
    object :callback, class: Proc, default: nil

    symbol :remote_database

    attr_accessor :identified_records
    attr_accessor :has_and_belongs_to_many_associations

    validate :id_xor_where_present?

    def execute
      puts 'Identifying records to sync...'
      @identified_records = Set[]
      @has_and_belongs_to_many_associations = {}

      remote do
        initial_query.each do |root_record|
          identify_associated_records(root_record, normalized_associations(association))
        end
      end

      puts "Identified #{identified_records.size} records to sync."

      callback.call(identified_records) if callback.present?

      sync_records
    end

    private

    def initial_query
      if id?
        klass.where(id: id)
      else
        klass.where(where)
      end
    end

    def id_xor_where_present?
      unless id? ^ where?
        errors.add(:id,
                   'Please provide either the id argument or the where argument, but not both.')
      end
    end

    def print_status
      print "\rIdentified #{identified_records.size} records..."
    end

    def identify_associated_records(root, associations)
      identified_records << root
      print_status

      standard_associations = associations.reject(&method(:includes_polymorphic_association))
      polymorphic_associations = associations.select(&method(:includes_polymorphic_association))

      standard_associations.each do |association|
        traverse_associations(root.class.eager_load(association).find(root.id), association)
      end

      identify_polymorphic_associated_records(root, polymorphic_associations)
    end

    def identify_polymorphic_associated_records(root, polymorphic_associations)
      polymorphic_associations.each do |polymorphic_association|
        if polymorphic_association.is_a?(Hash)
          polymorphic_association.each do |key, association|
            Array.wrap(root.__send__(key)).each do |target|
              identify_polymorphic_associated_records(target, Array.wrap(association))
            end
          end
        else
          target = root.__send__(polymorphic_association.property)
          next if target.nil?
          type = polymorphic_association.associations.keys.detect do |association_type|
            target.is_a?(association_type)
          end
          associations = polymorphic_association.associations[type]
          identify_associated_records(target, normalized_associations(associations))
        end
      end
    end

    def traverse_associations(records, associations)
      records = Array(records)

      identified_records.merge records
      print_status

      records.each do |record|
        associations.each do |association, nested_associations|
          if is_through_association?(record, association)
            traverse_associations(
              record.__send__(
                record.class.reflect_on_association(association).through_reflection.name
              ),
              associations
            )
          else
            associated_records = record.__send__(association)

            if is_has_and_belongs_to_many_association?(record, association)
              cache_has_and_belongs_to_many_association(record, association, associated_records)
            end

            traverse_associations(associated_records, nested_associations)
          end
        end
      end
    end

    def cache_has_and_belongs_to_many_association(record, association, associated_records)
      has_and_belongs_to_many_associations[record] ||= {}
      has_and_belongs_to_many_associations[record][association] = Array(associated_records)
    end

    def is_has_and_belongs_to_many_association?(record, association)
      record.class.reflect_on_association(association).class ==
        ActiveRecord::Reflection::HasAndBelongsToManyReflection
    end

    def is_through_association?(record, association)
      record.class.reflect_on_association(association).class ==
        ActiveRecord::Reflection::ThroughReflection
    end

    def sync_records
      ActiveRecord::Base.connection.disable_referential_integrity do
        classify_identified_instances.each do |class_name, new_instances|
          puts "Syncing #{new_instances.size} #{class_name} objects"
          clazz = Object.const_get(class_name)
          clazz.where(id: new_instances.map(&:id)).delete_all
          clazz.import(new_instances, validate: false)
        end

        has_and_belongs_to_many_associations.each do |record, associations|
          associations.each do |association, associated_records|
            local_record = record.class.find(record.id)
            local_associated_records = associated_records.map do |associated_record|
              associated_record.class.find(associated_record.id)
            end
            local_record.__send__(association) << local_associated_records
            local_record.save
          end
        end
      end
    end

    def classify_identified_instances
      puts "Classifying #{identified_records.size} records for bulk import..."

      identified_records.each_with_object({}) do |instance, memo|
        clazz = instance.class
        class_name = clazz.name
        memo[class_name] ||= []
        memo[class_name] << clone_instance(instance)
      end
    end

    def clone_instance(instance)
      clazz = instance.class
      new_instance = clazz.new

      instance.attributes.each do |attribute, value|
        new_instance[attribute.to_s] = value
      end

      new_instance
    end

    def includes_polymorphic_association(association)
      association.to_s.include?('Syncify::PolymorphicAssociation')
    end

    def normalized_associations(association)
      Syncify::NormalizeAssociations.run!(association: association)
    end

    def remote
      run_in_environment(remote_database) { yield }
    end

    def run_in_environment(environment)
      initial_config = ActiveRecord::Base.connection_config
      ActiveRecord::Base.establish_connection environment
      yield
    ensure
      ActiveRecord::Base.establish_connection initial_config
    end

  end
end
