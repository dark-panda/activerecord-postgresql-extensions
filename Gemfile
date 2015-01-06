source 'https://rubygems.org'

gemspec

if RUBY_PLATFORM == "java"
  gem "activerecord-jdbcpostgresql-adapter"
else
  gem "pg"
end

gem "rdoc", "~> 3.12"
gem "rake", "~> 10.0"
gem "minitest"
gem "minitest-reporters"
gem "guard-minitest"
gem "simplecov"

if File.exists?('Gemfile.local')
  instance_eval File.read('Gemfile.local')
end

