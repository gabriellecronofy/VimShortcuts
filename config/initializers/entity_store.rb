    module Cronofy
      require 'cronofy/denormalisers'
      require 'cronofy/services'

    class EntityStoreLogger
      include Hatchet

      [:debug, :info, :warn, :error, :fatal].each do |level|
        define_method(level) do |message, &block|
          log.add(level, message, &block)
        end
      end
    end

    class SequelLogger
      include Hatchet

      [:debug, :info, :warn, :error, :fatal].each do |level|
        define_method(level) do |message|
          log.add(:debug, message)
        end
      end
    end

    class Database
      attr_reader :connection_string
      def initialize(connection_string = "sqlite://dev.db")
        @connection_string = connection_string
      end

      def connection
        return @connection if @connection

        @connection ||= initiate_connection(connection_string: connection_string)
      end

      def initiate_connection(connection_string:, search_path: nil)
        connection ||= Sequel.connect(
          connection_string,
          search_path: search_path,
          test: false,
        )
        connection.logger = SequelLogger.new
        connection
      end
    end

    def self.configure
      yield self if block_given?

      EntityStoreSequel::PostgresEntityStore.database = Database.new.connection

      configure_entity_store

      Sequel.default_timezone = :utc
    end

    def self.configure_entity_store
      EntityStore::Config.setup do |config|
        config.logger = EntityStoreLogger.new
        config.store = EntityStoreSequel::PostgresEntityStore.new

        Denormalisers.all.each do |denormaliser|
          config.event_subscribers << denormaliser
        end

        Services.all.each do |service|
          config.event_subscribers << service
        end

        Cronofy.event_subscribers.each do |subscriber|
          config.event_subscribers << subscriber
        end
      end
    end

    def self.migrate_db(args = {})
      Sequel.extension :migration

      db = Database.new.connection

      migration_path = File.expand_path('../../db/migrations', __dir__)

      if args[:version]
        Sequel::Migrator.run(db, migration_path, target: args[:version].to_i)
      else
        Sequel::Migrator.run(db, migration_path)
      end
    end

    def self.event_subscribers
      []
    end

    configure
    end
