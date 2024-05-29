module Cronofy
  module LazyStores
    include Stores
    include LazyLoading

    def self.included(base)
      base.extend(ClassMethods)
    end

    lazy_new EntityStore::Store, :entity_store

    module ClassMethods
      def lazy_entity(key, &block)
        lazy_load(key) do
          entity_id = instance_eval(&block)
          case entity_id
          when String, NilClass
            case entity_id
            when Account.system.id
              Account.system
            else
              entity_store.get(entity_id)
            end
          else
            raise "Expected entity_id to be String but received #{entity_id.class}"
          end
        end
      end

      def lazy_entities(key, &block)
        lazy_load(key) do
          entity_ids = instance_eval(&block)
          case entity_ids
          when Array
            special_entities = []
            if entity_ids.delete(Account.system.id)
              special_entities << Account.system
            end
            entity_store.get_with_ids(entity_ids) + special_entities
          else
            raise "Expected entity_ids to be Array but received #{entity_ids.class}"
          end
        end
      end
    end
  end
end
