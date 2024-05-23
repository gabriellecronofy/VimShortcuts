    Sequel.migration do
      up do
        create_table "entities" do
          column :id, :char, primary_key: true, size: 24, null: false
          column :_type, :text, null: false
          column :version, :integer
          column :snapshot_key, :integer
          column :snapshot, :jsonb
        end

        create_table "entity_events" do
          column :id, :char, primary_key: true, size: 24, null: false
          column :_type, :text, null: false
          column :_entity_id, :char, size: 24, null: false
          column :entity_version, :integer
          column :snapshot, :jsonb
          column :at, :timestamp
        end
      end
    end
