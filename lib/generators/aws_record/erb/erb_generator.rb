# frozen_string_literal: true

require 'rails/generators/erb'
require 'rails/generators/resource_helpers'

module AwsRecord
  module Generators
    class ErbGenerator < Base
      include Rails::Generators::ResourceHelpers
      source_root File.expand_path('templates', __dir__)

      argument :attributes, type: :array, default: [], banner: 'field:type field:type'

      def initialize(args, *options)
        options[0] << '--skip-table-config'
        super
      end

      def create_root_folder
        empty_directory File.join('app/views', controller_file_path)
      end

      def copy_view_files
        available_views.each do |view|
          formats.each do |format|
            filename = filename_with_extensions(view, format)
            template filename, File.join('app/views', controller_file_path, filename)
          end
        end
      end

      private

      def available_views
        %w[index edit show new _form]
      end

      def formats
        [format]
      end

      def format
        :html
      end

      def handler
        :erb
      end

      def filename_with_extensions(name, file_format = format)
        [name, file_format, handler].compact.join('.')
      end
    end
  end
end
