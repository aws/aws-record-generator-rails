# frozen_string_literal: true

module AwsRecord
  module Generators
    class ActiveModel
      attr_reader :name

      def initialize(name)
        @name = name
      end

      # GET index
      def self.all(klass)
        "#{klass}.scan"
      end

      # GET show
      # GET edit
      # PATCH/PUT update
      # DELETE destroy
      def self.find(klass, attrs)
        hkey = attrs.select { |attr| attr.options[:hash_key] }[0]
        rkey = attrs.select { |attr| attr.options[:range_key] }
        rkey = rkey.empty? ? nil : rkey[0]

        if rkey
          "lambda {
              id = params[:id].split('&').map{ |param| CGI.unescape(param) }
              #{klass}.find(#{hkey.name}: id[0], #{rkey.name}: id[1])
            }.call()"
        else
          "#{klass}.find(#{hkey.name}: CGI.unescape(params[:id]))"
        end
      end

      # GET new
      # POST create
      def self.build(klass, params = nil)
        if params
          "#{klass}.new(#{params})"
        else
          "#{klass}.new"
        end
      end

      # POST create
      def save
        "#{name}.save"
      end

      # PATCH/PUT update
      def update(params = nil)
        "#{name}.update(#{params})"
      end

      # POST create
      # PATCH/PUT update
      def errors
        "#{name}.errors"
      end

      # DELETE destroy
      def destroy
        "#{name}.delete!"
      end
    end
  end
end
