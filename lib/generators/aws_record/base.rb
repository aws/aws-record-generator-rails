# frozen_string_literal: true

require 'rails/generators'

module AwsRecord
  module Generators
    class Base < Rails::Generators::NamedBase
      argument :attributes, type: :array, default: [], banner: 'field[:type][:opts]...',
                            desc: 'Describes the fields in the model'
      check_class_collision

      class_option :disable_mutation_tracking, type: :boolean, desc: 'Disables dirty tracking'
      class_option :timestamps, type: :boolean, desc: 'Adds created, updated timestamps to the model'
      class_option :table_config, type: :hash, default: {}, banner: 'primary:R-W [SecondaryIndex1:R-W]...',
                                  desc: 'Declares the r/w units for the model as well as any secondary indexes', required: true
      class_option :gsi, type: :array, default: [],
                         banner: 'name:hkey{field_name}[,rkey{field_name},proj_type{ALL|KEYS_ONLY|INCLUDE}]...', desc: 'Allows for the declaration of secondary indexes'
      class_option :table_name, type: :string, banner: 'model_table_name'
      class_option :password_digest, type: :boolean, desc: 'Whether to add a password_digest field to the model'

      class_option :required, type: :array, default: [], banner: 'field1...',
                              desc: 'A list of attributes that are required for an instance of the model'
      class_option :length_validations, type: :hash, default: {}, banner: 'field1:MIN-MAX...',
                                        desc: 'Validations on the length of attributes in a model'
      class_option :scaffold, type: :boolean, desc: 'Adds helper methods that scaffolding uses'

      attr_accessor :primary_read_units, :primary_write_units, :gsi_rw_units, :gsis, :required_attrs,
                    :length_validations

      private

      def initialize(args, *options)
        options[0] << '--skip-table-config' if options[1][:behavior] == :revoke
        @parse_errors = []

        super
        ensure_unique_fields
        ensure_hkey
        parse_gsis!
        parse_table_config!
        parse_validations!

        return if @parse_errors.empty?

        warn 'The following errors were encountered while trying to parse the given attributes'
        $stderr.puts
        warn @parse_errors
        $stderr.puts

        abort('Please fix the errors before proceeding.')
      end

      def parse_attributes!
        self.attributes = (attributes || []).map do |attr|
          GeneratedAttribute.parse(attr)
        rescue ArgumentError => e
          @parse_errors << e
          next
        end
        self.attributes = attributes.compact

        if options['password_digest']
          attributes << GeneratedAttribute.new('password_digest', :string_attr, digest: true)
        end

        return unless options['timestamps']

        attributes << GeneratedAttribute.parse('created:datetime:default_value{Time.now}')
        attributes << GeneratedAttribute.parse('updated:datetime:default_value{Time.now}')
      end

      def ensure_unique_fields
        used_names = Set.new
        duplicate_fields = []

        attributes.each do |attr|
          duplicate_fields << [:attribute, attr.name] if used_names.include? attr.name
          used_names.add attr.name

          next unless attr.options.key? :database_attribute_name

          raw_db_attr_name = attr.options[:database_attribute_name].delete('"') # db attribute names are wrapped with " to make template generation easier

          duplicate_fields << [:database_attribute_name, raw_db_attr_name] if used_names.include? raw_db_attr_name

          used_names.add raw_db_attr_name
        end

        return if duplicate_fields.empty?

        duplicate_fields.each do |invalid_attr|
          @parse_errors << ArgumentError.new("Found duplicated field name: #{invalid_attr[1]}, in attribute#{invalid_attr[0]}")
        end
      end

      def ensure_hkey
        uuid_member = nil
        hkey_member = nil
        rkey_member = nil

        attributes.each do |attr|
          if attr.options.key? :hash_key
            if hkey_member
              @parse_errors << ArgumentError.new("Redefinition of hash_key attr: #{attr.name}, original declaration of hash_key on: #{hkey_member.name}")
              next
            end

            hkey_member = attr
          elsif attr.options.key? :range_key
            if rkey_member
              @parse_errors << ArgumentError.new("Redefinition of range_key attr: #{attr.name}, original declaration of range_key on: #{hkey_member.name}")
              next
            end

            rkey_member = attr
          end

          uuid_member = attr if attr.name.include? 'uuid'
        end

        return if hkey_member

        if uuid_member
          uuid_member.options[:hash_key] = true
        else
          attributes.unshift GeneratedAttribute.parse('uuid:hkey')
        end
      end

      def mutation_tracking_disabled?
        options['disable_mutation_tracking']
      end

      def has_validations?
        !@required_attrs.empty? || !@length_validations.empty?
      end

      def parse_table_config!
        return unless options['table_config']

        @primary_read_units, @primary_write_units = parse_rw_units('primary')

        @gsi_rw_units = @gsis.to_h do |idx|
          [idx.name, parse_rw_units(idx.name)]
        end

        options['table_config'].each_key do |config|
          next if config == 'primary'

          gsi = @gsis.select { |idx| idx.name == config }

          @parse_errors << ArgumentError.new("Could not find a gsi declaration for #{config}") if gsi.empty?
        end
      end

      def parse_rw_units(name)
        if options['table_config'].key? name
          rw_units = options['table_config'][name]
          rw_units.gsub(/[,.-]/, ':').split(':').reject(&:empty?)
        else
          @parse_errors << ArgumentError.new("Please provide a table_config definition for #{name}")
        end
      end

      def parse_gsis!
        @gsis = (options['gsi'] || []).map do |raw_idx|
          idx = SecondaryIndex.parse(raw_idx)

          attributes = self.attributes.select { |attr| attr.name == idx.hash_key }
          if attributes.empty?
            @parse_errors << ArgumentError.new("Could not find attribute #{idx.hash_key} for gsi #{idx.name} hkey")
            next
          end

          if idx.range_key
            attributes = self.attributes.select { |attr| attr.name == idx.range_key }
            if attributes.empty?
              @parse_errors << ArgumentError.new("Could not find attribute #{idx.range_key} for gsi #{idx.name} rkey")
              next
            end
          end

          idx
        rescue ArgumentError => e
          @parse_errors << e
          next
        end

        @gsis = @gsis.compact
      end

      def parse_validations!
        @required_attrs = options['required']
        @required_attrs.each do |val_attr|
          @parse_errors << ArgumentError.new("No such field #{val_attr} in required validations") if attributes.none? do |attr|
            attr.name == val_attr
          end
        end

        @length_validations = options['length_validations'].map do |val_attr, bounds|
          @parse_errors << ArgumentError.new("No such field #{val_attr} in required validations") if attributes.none? do |attr|
            attr.name == val_attr
          end

          bounds = bounds.gsub(/[,.-]/, ':').split(':').reject(&:empty?)
          [val_attr, "#{bounds[0]}..#{bounds[1]}"]
        end
        @length_validations = @length_validations.to_h
      end
    end
  end
end
