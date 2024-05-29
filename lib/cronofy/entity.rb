module Cronofy
  module Entity
    def self.included(klass)
      klass.class_eval do
        include EntityStore::Entity
        include Hatchet
        include Assertive
        extend ClassMethods
        include Cronofy::CronofyAttributes

        attr_accessor :created
        attr_accessor :deleted
        attr_accessor :last_modified

        setup_delete klass.name
        setup_update_attributes klass.name

        def apply_event(event)
          super

          return unless event.respond_to?(:at) && event.at

          unless self.last_modified
            # Don't populate created if last_modified set previously as it
            # won't be accurate. The snapshot for the entity needs to be
            # invalidated instead so the entity is replayed from scratch.
            self.created = event.at
          end

          self.last_modified = event.at
        end

        def inspect
          to_s
        end

        def to_s
          "#<#{self.class} id=#{id || :unsaved}>"
        end
      end
    end

    module ClassMethods
      def simple_attribute(*names)
        names.each do |attr_name|
          define_simple_attribute(attr_name)
        end
      end

      def define_simple_attribute(attr_name)
        define_simple_attribute_class(attr_name)

        define_method("set_#{attr_name}") do |by, at, value|
          return if value == send(attr_name)
          set_class = Utils.get_type_constant("#{self.class.name}#{Utils.camelcase(attr_name)}Set")
          set_event = set_class.new(by: by.id, at: at, attr_name => value)
          record_event set_event
        end

        attr_accessor attr_name
      end

      def define_simple_attribute_class(attr_name)
        setter_event_class = Utils.set_type_constant("#{self.name}#{Utils.camelcase(attr_name)}Set")

        setter_event_class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        include EntityStore::Event

        attr_accessor :by, attr_name
        time_attribute :at

        def apply(entity)
        entity.send(\"#{attr_name}=\", send(\"#{attr_name}\"))
      end
        RUBY
      end

      def boolean_attribute(name, opts = {})
        simple_attribute(name)

        define_method(name) do
          value = instance_variable_get("@#{name}")

          if value.nil?
            opts.fetch(:default_value, false)
          else
            value
          end
        end

        alias_method "#{name}?", name
      end

      def symbol_attribute(*names)
        simple_attribute(*names)

        names.each do |name|
          define_method("#{name}=") do |value|
            instance_variable_set("@#{name}", value ? value.to_sym : nil)
          end
        end
      end

      def symbol_array_attribute(*names)
        names.each do |name|
          define_method(name) do
            instance_variable_get("@#{name}") || instance_variable_set("@#{name}", [])
          end
          define_method("#{name}=") do |value|
            instance_variable_set("@#{name}", value ? value.map(&:to_sym) : [])
          end
        end
      end

      def symbol_hash_attribute(*names)
        names.each do |name|
          attr_reader name
          define_method("#{name}=") do |value|
            instance_variable_set("@#{name}", value ? Utils.dup_with_symbolized_keys(value) : {})
          end
        end
      end

      def setup_delete(klass)
        delete_event_class = Utils.set_type_constant("#{klass}Deleted")
        delete_event_class.class_eval do
          include Cronofy::EntityEvent

          def apply(entity)
            entity.deleted = true
          end
        end

        define_method(:deleted?) { @deleted }

        # Public: attempts to delete the entity. Requires an appropriately named
        # event class to be available for instantiation
        #
        # by      - User deleting the Model
        # at      - Time the Model was deleted
        #
        # Returns nothing
        define_method("delete") do |by, at|
          record_event(delete_event_class.new(by: by.respond_to?(:id) ? by.id : by, at: at))
          self
        end
      end

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def setup_update_attributes(klass)
        update_attributes_event_class = Utils.set_type_constant("#{klass}AttributesUpdated")

        update_attributes_event_class.class_eval do
          include EntityStore::Event

          attr_accessor :updated_by, :attrs
          time_attribute :updated_at

          def apply(entity)
            # allowed this to accept hash or array of pairs
            attrs.each { |item| entity.send("#{item[0]}=", item[1]) }
          end
        end

        # Public: iterates through the attributes hash and calls
        # explicit setter methods according to the convention set_[attribute name]
        # if not present then attempts to call property setter [attribute name]=
        # otherwise throws an exception
        define_method("update_attributes") do |updated_by, updated_at, attrs|
          updates = {}
          attrs.each_pair do |key, value|
            next unless self.respond_to?(key) && self.send(key) != value

            if self.respond_to?("set_#{key}")
              self.send("set_#{key}", updated_by, updated_at, value)
            elsif self.respond_to?("#{key}=")
              updates[key] = value
            else
              raise StandardError, "Attribute [#{key}] not recognised"
            end
          end

          unless updates.empty?
            event_attrs = {
              updated_by: updated_by.respond_to?(:username) ? updated_by.username : updated_by,
              updated_at: updated_at,
              attrs: updates,
            }
            record_event(update_attributes_event_class.new(event_attrs))
          end
          self
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def account_roles(roles)
        roles.each do |role|
          define_role_specific_methods(role)
        end

        define_method("add_account_role") do |by, at, account, role|
          send("add_#{role}", by, at, account)
        end

        define_method("remove_account_role") do |by, at, account_id, role|
          send("remove_#{role}_id", by, at, account_id)
        end

        define_method("remove_account_from_all_roles") do |by, at, account_id|
          roles.each do |role|
            send("remove_#{role}_id", by, at, account_id, true)
          end
        end

        remove_all_class = Utils.set_type_constant("#{self.name}AllAccountRolesRemoved")

        clear_role_calls = roles.map do |role|
          "entity.#{role}_ids.clear"
        end

        remove_all_class_body = %"
          include Cronofy::EntityEvent

          def apply(entity)
          #{clear_role_calls.join(' ; ')}
          end
          "

        remove_all_class.class_eval(remove_all_class_body, __FILE__, __LINE__ + 1)

        define_method("remove_all_account_roles!") do |by, at|
          record_event remove_all_class.new(by: by.id, at: at)
        end
      end

      def define_role_specific_methods(role)
        attr_name = "#{role}_id".to_sym
        array_name = "#{role}_ids".to_sym

        attr_writer array_name
        define_method(array_name) do
          instance_variable_get("@#{array_name}") || instance_variable_set("@#{array_name}", [])
        end

        define_method("#{role}?") do |account|
          send(array_name).include?(account.id)
        end

        define_account_role_add_method(role, attr_name, array_name)
        define_account_role_remove_method(role, attr_name, array_name)
      end

      def define_account_role_add_method(role, attr_name, array_name)
        event_class = Utils.set_type_constant("#{self.name}#{Utils.camelcase(role)}Added")

        event_class_body = %"
          include Cronofy::EntityEvent

          attr_accessor :#{attr_name}

          def apply(entity)
          entity.#{array_name} << #{attr_name}
          entity.#{array_name}.uniq!
          end

          alias_method :account_id, :#{attr_name}
          "

        event_class.class_eval(event_class_body, __FILE__, __LINE__ + 1)

        define_method("add_#{role}") do |by, at, account|
          return if send(array_name).include?(account.id)

          add_class = Utils.get_type_constant("#{self.class.name}#{Utils.camelcase(role)}Added")
          add_event = add_class.new(by: by.id, at: at, attr_name => account.id)
          record_event add_event
        end
      end

      def define_account_role_remove_method(role, attr_name, array_name)
        event_class = Utils.set_type_constant("#{self.name}#{Utils.camelcase(role)}Removed")

        event_class_body = %"
          include Cronofy::EntityEvent

          attr_accessor :#{attr_name}

          def apply(entity)
          entity.#{array_name}.delete(#{attr_name})
          end

          alias_method :account_id, :#{attr_name}
          "

        event_class.class_eval(event_class_body, __FILE__, __LINE__ + 1)

        define_method("remove_#{role}_id") do |by, at, account_id, skip_check = false|
          if skip_check
            return unless send(array_name).include?(account_id)
          else
            assert! send(array_name).include?(account_id), "#{role}=#{account_id} not a #{role}"
          end

          remove_class = Utils.get_type_constant("#{self.class.name}#{Utils.camelcase(role)}Removed")
          remove_event = remove_class.new(by: by.id, at: at, attr_name => account_id)
          record_event remove_event
        end
      end
    end

    # Public: default implementation iterates through all public setters
    #
    def to_hash
      attributes
    end

    def to_param
      id
    end

    def encryption_iv
      raise StandardError, "Entity must be saved before requesting an encryption iv" unless id
      id
    end

    def generate_an_id
      BSON::ObjectId.new.to_s
    end

    def ==(other)
      case other
      when Entity
        # Basic equality check of entities
        [self.id, self.version] == [other.id, other.version]
      else
        false
      end
    end
  end
end
