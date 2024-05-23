    namespace :database do
    desc "migrates the database schema to the latest version"
      task :migrate => [:environment] do
        Cronofy.migrate_db
      end

      desc "seed the database"
      task :seed => [:migrate] do
        by = "Gabby"
        at = Time.now
        shortcut = "dd"
        shortcut_name = "delete line"
        Shortcut.create(by, at, shortcut, shortcut_name)
      end
    end
