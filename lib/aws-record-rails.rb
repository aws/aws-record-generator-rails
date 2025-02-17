# frozen_string_literal: true

require_relative 'generators/generated_attribute'
require_relative 'generators/secondary_index'
require_relative 'generators/aws_record/base'

require_relative 'generators/aws_record/model/model_generator'
require_relative 'generators/aws_record/resource/resource_generator'
require_relative 'generators/aws_record/erb/erb_generator'
require_relative 'generators/aws_record/scaffold/scaffold_generator'
require_relative 'generators/aws_record/scaffold_controller/scaffold_controller_generator'

require 'aws-record'

module Aws
  module Record
    # Rails tasks for Aws::Record
    class Railtie < ::Rails::Railtie
      VERSION = File.read(File.expand_path('../VERSION', __dir__)).strip

      rake_tasks do
        load 'tasks/aws_record/migrate.rake'
      end
    end
  end
end
