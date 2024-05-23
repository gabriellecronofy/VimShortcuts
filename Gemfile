source "https://rubygems.org"

ruby "3.1.4"

gem "rails", "~> 7.1.3", ">= 7.1.3.3"

gem "sprockets-rails"

gem "puma", ">= 5.0"

gem "importmap-rails"



gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "bootsnap", require: false

group :development, :test do
    gem "debug", platforms: %i[ mri windows ]
end

group :development do
    gem "web-console"

    
    

end

group :test do


end
gem "sqlite3"
gem "entity_store_sequel"
gem "hatchet", git: "https://github.com/cronofy/hatchet.git", branch: "master"
gem "sassc-rails"
gem "flipper"
gem "flipper-redis"
gem "flipper-ui"

group :test, :development do
  gem "byebug"
  gem "fuubar"
  gem "i18n-tasks"
  gem "listen"
  gem "rails-controller-testing", ["~> 1.0", ">= 1.0.5"]
  gem "rb-readline"
  gem "rspec-rails"
  gem "rspecq"
  gem "spring"
  gem "spring-commands-rspec"
  gem "term-ansicolor"
  gem "solargraph", ">= 0.48.0"
  gem "solargraph-rails"
  gem "pry-byebug"
  gem "pry-rails"
  gem "amazing_print"
end

group :test do
  gem "fakeredis", require: "fakeredis/rspec"
  gem "hashie"
  gem "webmock"
end

group :ci do
  gem "rspec_junit_formatter"
end
