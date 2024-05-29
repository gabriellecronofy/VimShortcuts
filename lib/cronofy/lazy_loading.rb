module Cronofy
  module LazyLoading
    def self.included(base)
      base.extend(LazyLoading)
    end

    def lazy_load(key, &block)
      define_method(key) do
        @__lazily_loaded ||= {}

        if not @__lazily_loaded.key?(key)
          @__lazily_loaded[key] = instance_eval(&block)
        else
          @__lazily_loaded[key]
        end
      end

      define_method("set_#{key}!") do |value|
        @__lazily_loaded[key] = value
      end
    end

    def lazy_new(klass, key = nil)
      key ||= (klass.name.split("::").last).gsub(/([a-z])([A-Z])/,'\1_\2').downcase
      lazy_load(key.to_sym) { klass.new }
    end

    def lazy_env(*keys)
      keys.each do |key|
        lazy_load(key.downcase.to_sym) { ENV[key] }
      end
    end
  end
end
