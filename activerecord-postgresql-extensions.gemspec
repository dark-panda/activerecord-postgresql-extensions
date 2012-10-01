# -*- encoding: utf-8 -*-

require File.expand_path('../lib/active_record/postgresql_extensions/version', __FILE__)

Gem::Specification.new do |s|
  s.name = "activerecord-postgresql-extensions"
  s.version = ActiveRecord::PostgreSQLExtensions::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["J Smith"]
  s.description = "A whole bunch of extensions the ActiveRecord PostgreSQL adapter."
  s.summary = s.description
  s.email = "code@zoocasa.com"
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = `git ls-files`.split($\)
  s.executables = s.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  s.test_files = s.files.grep(%r{^(test|spec|features)/})
  s.homepage = "http://github.com/zoocasa/activerecord-postgresql-extensions"
  s.require_paths = ["lib"]

  s.add_dependency("activerecord", [">= 2.3"])
  if RUBY_PLATFORM == "java"
    s.add_dependency("activerecord-jdbcpostgresql-adapter")
  else
    s.add_dependency("pg")
  end
  s.add_dependency("rdoc")
  s.add_dependency("rake", ["~> 0.9"])
  s.add_dependency("minitest")
  s.add_dependency("turn")
end

