# frozen_string_literal: true

require 'active_record_survey/version'

module ActiveRecordSurvey
  module Compatibility
    if ActiveSupport::VERSION::MAJOR >= 4
      require 'active_support/proxy_object'

      def self.executable_prefix
        'bin'
      end

      def self.proxy_object_class
        ActiveSupport::ProxyObject
      end
    else
      require 'active_support/basic_object'

      def self.executable_prefix
        'script'
      end

      def self.proxy_object_class
        ActiveSupport::BasicObject
      end
    end
  end
end
