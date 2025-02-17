# frozen_string_literal: true

require 'rails/generators/resource_helpers'
require 'generators/aws_record/active_model'

module AwsRecord
  module Generators
    class ScaffoldControllerGenerator < Base
      include Rails::Generators::ResourceHelpers
      source_root File.expand_path('templates', __dir__)

      check_class_collision suffix: 'Controller'

      class_option :helper, type: :boolean
      class_option :orm, banner: 'NAME', type: :string, required: true,
                         desc: 'ORM to generate the controller for'
      class_option :api, type: :boolean,
                         desc: 'Generates API controller'

      argument :attributes, type: :array, default: [], banner: 'field:type field:type'

      def initialize(args, *options)
        options[0] << '--skip-table-config'
        super
      end

      def create_controller_files
        template_file = options.api? ? 'api_controller.rb' : 'controller.rb'
        template template_file,
                 File.join('app/controllers', controller_class_path, "#{controller_file_name}_controller.rb")
      end

      hook_for :template_engine, in: :aws_record do |template_engine|
        invoke template_engine unless options.api?
      end

      hook_for :test_framework, as: :scaffold

      # Invoke the helper using the controller name (pluralized)
      hook_for :helper, as: :scaffold, in: :rails do |invoked|
        invoke invoked, [controller_name]
      end

      private

      def orm_class
        @orm_class = AwsRecord::Generators::ActiveModel
      end
    end
  end
end
