
module PostgreSQLExtensions::ActiveRecord
	# The ForeignKeyAssociations module attempts to automatically create
	# associations based on your database schema by looking at foreign key
	# relationships. It can be enabled by setting the
	# enable_foreign_key_associations configuration option on
	# ActiveRecord::Base to true.
	#
	# The ForeignKeyAssociations isn't a replacement for hand-coded
	# associations, as it specifically won't override any associations you
	# create in your models, but can serve to keep your models a little more
	# up-to-date by using the database itself as a means to creating
	# associations.
	#
	# Foreign key associations are formed by looking at various system tables
	# in your database and attempting to make sane decisions based on how
	# foreign key relationships and indexes are created. We basically go by the
	# following rules:
	#
	# * a foreign key reference will create a belongs_to on the model doing
	#   the referencing as well as either a has_one or has_many association
	#   on the referenced table. If there is a UNIQUE index on the foreign key
	#   column, we use a has_one association; otherwise, we use a has_many.
	# * "has_many :through" associations are found using multi-column UNIQUE
	#   indexes and existing associations which are either found during the
	#   first stages of our process or are pre-existing.
	#
	# Using PostgreSQL as an example:
	#
	#	CREATE TABLE "foos" (
	#	  id serial NOT NULL PRIMARY KEY
	#	);
	#
	#	CREATE TABLE "bars" (
	#	  id serial NOT NULL PRIMARY KEY,
	#	  foo_id integer NOT NULL REFERENCES "foo"("id")
	#	);
	#
	# In this case, we will attempt to create the following associations:
	#
	#	# Foo model:
	#	has_many :bars
	#
	#	# Bar model:
	#	belongs_to :foo
	#
	# If we were to add a UNIQUE index on the foo_id column in bars, we
	# would get a has_one assocation in the foos model:
	#
	#	CREATE TABLE "bars" (
	#	  id serial NOT NULL PRIMARY KEY,
	#	  foo_id integer NOT NULL REFERENCES "foo"("id") UNIQUE
	#	);
	#	# or ALTER TABLE or CREATE UNIQUE INDEX, whatever
	#
	# Produces the following associations:
	#
	#	# Foo model:
	#	has_one :bars
	#
	#	# Bar model:
	#	belongs_to :foo
	#
	# We also attempt to do "has_many :through" associations by looking for
	# things like UNIQUE indexes on multiple columns, previously existing
	# associations and model names. For instance, given the following
	# schema:
	#
	#	CREATE TABLE "foos" (
	#	  id serial NOT NULL PRIMARY KEY
	#	);
	#
	#	CREATE TABLE "bars" (
	#	  id serial NOT NULL PRIMARY KEY
	#	);
	#
	#	CREATE TABLE "foo_bars" (
	#	  id serial NOT NULL PRIMARY KEY,
	#	  foo_id integer NOT NULL REFERENCES "foos"("id"),
	#	  bar_id integer NOT NULL REFERENCES "bars"("id"),
	#	  UNIQUE ("foo_id", "bar_id")
	#	);
	#
	# Would create the following associations:
	#
	#	# FooBar model:
	#	belongs_to :foo
	#	belongs_to :bar
	#
	#	# Foo model:
	#	has_many :foo_bars
	#	has_many :bars, :through => :foo_bars
	#
	#	# Bar model:
	#	has_many :foo_bars
	#	has_many :foos, :through => :foo_bars
	#
	# The rules for association creation through foreign keys are fairly lax,
	# i.e. you don't need to name your keys "something_id" as Rails generally
	# demands by default. About the only thing that would really help us find
	# foreign key associations is the naming used by your models: if they
	# don't match up with the Rails conventions for model-to-table mapping
	# (pluralization, underscores, etc.), we can get confused and may miss
	# some associations. The associations will eventually be created once
	# all of your models are loaded, but as of Rails 2.0 we can't guarantee
	# when and if all of your models will load before we try to find our
	# foreign keys, so bear that in mind when using this plugin. The only time
	# this really comes up is when you're using set_table_name in a model to
	# override the Rails conventions and we can't figure that out during our
	# foreign key hunt.
	#
	# Note that this plugin will never try to override existing associations.
	# If you have an existing association with the same name as one that we
	# are trying to create (or for that matter, a method with the same name)
	# then we will just silently and happily skip that association.
	#
	# Portions of this plugin were inspired by the RedHill on Rails plugins
	# available at http://www.redhillonrails.org/. The idea is basically
	# the same in both cases, although our implementations are rather
	# different both in terms of structure and functionality, as this plugin
	# is more specific to our particular needs.
	module ForeignKeyAssociations
		def self.included(base)
			base.extend(ClassMethods)
		end

		module ClassMethods
			def self.extended(base)
				class << base
					alias_method_chain :allocate, :foreign_keys
					alias_method_chain :new, :foreign_keys
					alias_method_chain :reflections, :foreign_keys
				end
			end

			def allocate_with_foreign_keys #:nodoc:
				load_foreign_key_associations if load_foreign_key_associations? && !@foreign_key_associations_loaded
				allocate_without_foreign_keys
			end

			def new_with_foreign_keys(*args) #:nodoc:
				load_foreign_key_associations if load_foreign_key_associations? && !@foreign_key_associations_loaded
				new_without_foreign_keys(*args) { |*block_args|
					yield(*block_args) if block_given?
				}
			end

			def reflections_with_foreign_keys #:nodoc:
				load_foreign_key_associations if load_foreign_key_associations? && !@foreign_key_associations_loaded
				reflections_without_foreign_keys
			end

			# Returns an Array of foreign keys referencing this model. See
			# ActiveRecord::Base#referenced_foreign_keys for details.
			def referenced_foreign_keys
				@referenced_foreign_keys ||= connection.referenced_foreign_keys(table_name, "#{name} Referenced Foreign Keys")
			end

			# Returns an Array of foreign keys in this model. See
			# ActiveRecord::Base#foreign_keys for details.
			def foreign_keys
				@foreign_keys ||= connection.foreign_keys(table_name, "#{name} Foreign Keys")
			end

			# Allows you to selectively disable foreign key association loading
			# when the ActiveRecord setting enable_foreign_key_associations
			# is enabled. This works on a per-model basis, and prevents any
			# foreign key associations from being created on this model. This
			# applies to both foreign keys that reference this model as well
			# as foreign keys within the model itself.
			def dont_load_foreign_key_associations!
				@load_foreign_key_associations = false
			end

			# Creates foreign key associations for the model. This is
			# essentially a three-step process:
			#
			# 1. Find any tables that reference this model via foreign keys
			#    and create the associations accordingly.
			# 2. Find any foreign keys in this model and create the
			#    associations accordingly. This process creates both belongs_to
			#    associations on this model to the referenced models as well
			#    as has_many/has_one associations on the referenced models
			#    themselves. To determine whether the association is a has_many
			#    or a has_one, we take a look at UNIQUE indexes created on the
			#    table column. In cases where the index is UNIQUE, we create
			#    a has_one association; in all others, we create a has_many
			#    association.
			# 3. Look at the model itself and try to determine whether or not
			#    we have a "has_many :through" association. We make this
			#    determination by looking to see if there are two foreign
			#    keys with the following conditions:
			#    * the model has an index with exactly two columns in it and
			#      the index itself is UNIQUE;
			#    * we've already created a belongs_to association with each
			#      column and the column names match the columns in the UNIQUE
			#      index; and
			#    * the model name is either "FirstModelSecondModel" or
			#      "SecondModelFirstModel".
			#    If these criteria match, then the "has_many :through"
			#    associations are created on both of the referenced models.
			#
			# In all cases, we respect any dont_load_foreign_key_associations!
			# settings on individual models as well as take into account
			# existing associations with the same names as the ones we're going
			# to try to create. In other words, if you already have an
			# association called :listings on a model and we find a foreign
			# key that matches, we won't blow away your existing association
			# and instead just continue along merrily.
			def load_foreign_key_associations
				return if @foreign_key_associations_loaded
				@foreign_key_associations_loaded = true

				indexes = connection.indexes(table_name, "#{name} Indexes")

				# This does the associations for the tables that reference
				# columns in this table.
				referenced_foreign_keys.each do |fk|
					begin
						referencing_class = compute_type(fk[:table].classify)
						referencing_class.load_foreign_key_associations if referencing_class.load_foreign_key_associations?
					rescue NameError
						# Do nothing. We won't bother creating associations
						# if the model class itself doesn't exist.
					end
				end

				# This does the foreign key associations for this model.
				foreign_keys.each do |fk|
					belongs_to_association_id = fk[:table].singularize.to_sym
					begin
						references_class_name = fk[:table].classify
						references_class = compute_type(references_class_name)

						unless method_defined?(belongs_to_association_id)
							belongs_to(
								belongs_to_association_id,
								:class_name => references_class_name,
								:foreign_key => fk[:column]
							)
						end

						# If we have a unique index for this column, we'll
						# create a has_one association; otherwise, it's a
						# has_many.
						if indexes.detect { |i|
							i.columns.length == 1 && i.unique && i.columns.include?(fk[:column])
						}
							has_association_id = self.name.demodulize.underscore.to_sym
							unless references_class.method_defined?(has_association_id)
								references_class.has_one(
									has_association_id, {
										:class_name => name,
										:foreign_key => fk[:column]
									}
								)
							end
						else
							has_association_id = self.name.demodulize.underscore.pluralize.to_sym
							unless references_class.method_defined?(has_association_id)
								references_class.has_many(
									has_association_id, {
										:class_name => name,
										:foreign_key => fk[:column]
									}
								)
							end
						end
					rescue NameError
						# Do nothing. NOTHING! We don't want to create
						# associations on non-existent classes.
					end
				end

				# If we have an index that contains exactly two columns and
				# it's a UNIQUE index, then we might have a
				# "has_many :through" association, so let's look for it now.
				if through = indexes.detect { |i| i.columns.length == 2 && i.unique }
					catch :not_a_has_many_through do
						hmt_associations = []

						# This will loop through the columns in the UNIQUE
						# index and see if they're both foreign keys
						# referencing other tables.
						through.columns.each do |c|
							if foreign_keys.detect { |fk| fk[1] == c }.blank?
								throw(:not_a_has_many_through)
							end

							# Check that both columns have belongs_to
							# associations.
							unless hmt_association = reflections.detect { |r, v|
								v.macro == :belongs_to && v.primary_key_name == c
							}
								throw(:not_a_has_many_through)
							end

							hmt_associations << hmt_association
						end

						hmt_first = hmt_associations.first
						hmt_second = hmt_associations.last

						hmt_first_association_id = hmt_second.first.to_s.pluralize.to_sym
						hmt_second_association_id = hmt_first.first.to_s.pluralize.to_sym

						hmt_first_class = hmt_first.last.name.constantize
						hmt_second_class = hmt_second.last.name.constantize

						# Check to see if this model is named
						# "FirstModelSecondModel" or "SecondModelFirstModel".
						if strict_foreign_key_has_many_throughs
							unless [
								"#{hmt_first_class}#{hmt_second_class}",
								"#{hmt_second_class}#{hmt_first_class}"
							].include?(self.name)
								throw(:not_a_has_many_through)
							end
						end

						# If we haven't thrown up, we can create the
						# associations, assuming they don't already exist and
						# we're allowed to.
						through_association_id = self.name.demodulize.underscore.pluralize.to_sym

						if hmt_first_class.load_foreign_key_associations?
							unless hmt_first_class.method_defined?(hmt_first_association_id)
								hmt_first_class.has_many(
									hmt_first_association_id,
									:through => through_association_id
								)
							end
						end

						if hmt_second_class.load_foreign_key_associations?
							unless hmt_second_class.method_defined?(hmt_second_association_id)
								hmt_second_class.has_many(
									hmt_second_association_id,
									:through => through_association_id
								)
							end
						end
					end
				end
			end

			# Should we load a model's foreign key associations? Maybe we
			# should, and maybe we shouldn't.
			def load_foreign_key_associations?
				ActiveRecord::Base.enable_foreign_key_associations &&
					!abstract_class? && (
						@load_foreign_key_associations.nil? || @load_foreign_key_associations
					)
			end
		end
	end
end

ActiveRecord::Base.class_eval do
	# Enable foreign key associations.
	cattr_accessor :enable_foreign_key_associations

	# Be a bit stricter when looking for "has_many :through" associations by
	# checking the name of the through model for the Rails-like naming
	# convention of "FirstModelSecondModel".
	cattr_accessor :strict_foreign_key_has_many_throughs
end
