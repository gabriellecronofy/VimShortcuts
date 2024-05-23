    namespace :database do
    desc "migrates the database schema to the latest version"
      task :migrate => [:environment] do
        Cronofy.migrate_db
      end
    end
