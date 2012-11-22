source 'https://rubygems.org'

gemspec

if RUBY_PLATFORM == "java"
  gem "activerecord-jdbcpostgresql-adapter"
else
  gem "pg"
end

gem "rdoc"
gem "rake", ["~> 0.9"]
gem "minitest"
gem "minitest-reporters"
gem "guard-minitest"

if RbConfig::CONFIG['host_os'] =~ /^darwin/
  gem "rb-fsevent"
  gem "growl"
end

