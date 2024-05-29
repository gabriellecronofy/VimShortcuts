module Cronofy
  module Assertive
    def self.included(base)
      base.extend(Assertive)
    end

    private

    def assert!(predicate, message)
      return if predicate

      raise ArgumentError, message
    end

    def assert_fetch!(hash, key, message = nil)
      hash.fetch(key) do
        message ||= "#{key} must be defined"
        raise ArgumentError, message
      end
    end

    def assert_string_with_value!(value, message = "String must have value")
      return if value.is_a?(String) && value.strip != ""

      raise ArgumentError, message
    end

    def assert_object_id!(value, attribute_name)
      return if BSON::ObjectId.legal?(value)

      raise ArgumentError, "#{attribute_name} must be a valid BSON object ID"
    end

    def assert_boolean!(value, attribute_name)
      return if [true, false].include?(value)

      raise ArgumentError, "#{attribute_name} must be a boolean"
    end

    def refute!(predicate, message)
      assert! !predicate, message
    end
  end
end
