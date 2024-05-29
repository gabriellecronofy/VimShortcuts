module Cronofy
  module Stores
    module PostgresStore
      def self.included(klass)
        klass.class_eval do
          include Hatchet
          extend ClassMethods
        end
      end

      class UniqueIndexViolationError < StandardError
      end

      ENTITY_BATCH_SIZE = 50

      module ClassMethods
        def set_collection_name(name)
          @_collection_name = name
        end

        def collection_name
          @_collection_name
        end
      end

      def open_connection
        Cronofy.postgres_connection
      end

      def open_read_connection
        Cronofy.postgres_read_connection
      end

      def collection_name
        self.class.collection_name
      end

      def collection
        @_collection ||= open_connection[self.collection_name]
      end

      def read_collection
        @_read_collection ||= open_read_connection[self.collection_name]
      end

      def entity_store
        @_entity_store ||= EntityStore::Store.new
      end

      def promoted_columns
        []
      end

      def promoted_data_columns
        []
      end

      def promote_columns(source, result)
        (promoted_columns + promoted_data_columns).each do |key|
          if source.key?(key) || source.key?(key.to_s)
            value = (source.delete(key.to_s) || source.delete(key))
            result[key] = value
          end
        end
      end

      def data_rows_to_objects(rows, klass)
        rows.map do |row|
          data_row_to_object(row, klass)
        end
      end

      def data_row_to_object(row, klass)
        result = merge_columns(row, row[:data])
        klass.new(result)
      end

      def merge_columns(source, result)
        result ||= {}

        # Ensure plain Hash rather than Sequel::Postgres::JSONBHash or similar
        result = result.to_h

        promoted_columns.each do |key|
          if source.key?(key)
            result[key] = source[key]
          end
        end

        promoted_data_columns.each do |key|
          next unless source.key?(key)
          if source[key].nil?
            result[key] ||= result[key.to_s]
          else
            result[key] = source[key]
          end
        end

        result
      end

      class PaginatedDataSet
        attr_reader :current_page
        attr_reader :page_count
        attr_reader :record_count
        attr_reader :page_size
        attr_reader :page

        def initialize(current_page, query)
          @current_page = current_page
          @page_count = query.page_count
          @record_count = query.pagination_record_count
          @page_size = query.page_size
          @page = query.current_page
        end
      end

      def get(id)
        entity_store.get(id)
      end

      def get_with_ids(ids)
        entity_store.get_with_ids(ids)
      end

      def update(id, version, fields)
        fields = fields.merge(version: version)
        update_existing(id, fields)
      end

      def upsert(id, fields, row_fields = {})
        prepare_hashes(fields, row_fields)

        if existing = collection.where(id: id.to_s).first
          update_impl(id, fields, existing, row_fields)
        else
          doc = row_fields.merge(data: PigeonHole.generate(fields),
            id: id.to_s)
          collection.insert(doc)
        end
      end

      def update_existing(id, fields, row_fields = {})
        prepare_hashes(fields, row_fields)

        if existing = collection.where(id: id.to_s).first
          update_impl(id, fields, existing, row_fields)
        end
      end

      def delete(id)
        collection.where(id: id.to_s).delete
      end

      def all
        data_rows_to_objects(collection.all, DataObject)
      end

      def all_each
        collection.use_cursor(hold: true).each do |item|
          yield data_row_to_object(item, DataObject)
        end
      end

      def all_ids(args)
        collection.where(args).select(:id).use_cursor(hold: true).each do |row|
          yield(row[:id])
        end
      end

      def delete_with_cursor(args)
        all_ids(args) do |id|
          collection.where(id: id).delete
        end
      end

      def all_entities(args, &block)
        buffer = []

        all_ids(args) do |id|
          buffer << id
          next unless buffer.length == ENTITY_BATCH_SIZE

          get_with_ids(buffer).each(&block)
          buffer.clear
        end

        get_with_ids(buffer).each(&block)
        nil
      end

      def count(query = nil)
        if query
          collection.where(query).count
        else
          collection.count
        end
      end

      def exists_in_collection?(query)
        !collection.where(query).empty?
      end

      alias exists? exists_in_collection?

      # Public : Clears the store
      #
      def reset!
        collection.truncate
      end

      def prepare_hashes(fields, row_fields)
        promote_columns(fields, row_fields)

        fields.delete('_id')
        row_fields.delete(:id)

        row_fields.each do |k, v|
          case v
          when Array
            row_fields[k] = Sequel.pg_array(v, "text")
          when Symbol
            row_fields[k] = v.to_s
          end
        end
      end

      def transaction(&block)
        open_connection.transaction(&block)
      end

      protected def search_fragment(text)
        escaped_text = text.gsub(/[\\%_]/) {|m| "\\#{m}"}
        "%#{escaped_text}%"
      end

      private

      def update_impl(id, fields, existing, row_fields)
        existing_hash = HashUtils.symbolize_keys(existing[:data] || {})
        symbolized_fields = HashUtils.symbolize_keys(fields)

        new_hash = existing_hash.merge(symbolized_fields)

        if existing_hash == new_hash
          row_fields.delete(:data)
        else
          row_fields[:data] = PigeonHole.generate(new_hash)
        end

        if row_fields.any?
          collection.where(id: id.to_s).update(row_fields)
        end
      end

      def escape_like(*values)
        values.flatten.map { |value| collection.escape_like(value) }
      end
    end
  end
end
