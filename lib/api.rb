require "grape"
require "service-discovery"
require "workflow_server"
require "api/workflows"
require "api/events"
require "api/debug"
require 'api/middleware/log'
require 'api/middleware/health'
require 'api/middleware/heartbeat'
require 'api/middleware/delayed_job_stats'
require 'api/middleware/sidekiq_stats'
require 'api/middleware/camel_json_formatter'
require 'api/middleware/authenticate'
require 'api/middleware/camel_case'
require 'api/middleware/clear_session'

module Api
  class App < Grape::API
    ServiceDiscovery::Description.disable! if WorkflowServer::Config.environment == :production

    def self.namespace_desc(description)
      @namespace_description = { namespace_description: description }
    end

    format :json

    before do
      ::WorkflowServer::Helper::HashKeyTransformations.underscore_keys(params)
    end

    rescue_from :all do |e|
      p e
      WorkflowServer::BaseLogger.error({error_type: e.class, error: e.message, backtrace: e.backtrace})
      Rack::Response.new({error: e.message }.to_json, 500, { "Content-type" => "application/json" }).finish
    end

    rescue_from WorkflowServer::EventNotFound do |e|
      WorkflowServer::BaseLogger.info(e)
      Rack::Response.new({error: e.message }.to_json, 404, { "Content-type" => "application/json" }).finish
    end

    RESCUED_ERRORS = [
      WorkflowServer::EventComplete,
      WorkflowServer::InvalidParameters,
      WorkflowServer::InvalidEventStatus,
      WorkflowServer::InvalidOperation,
      WorkflowServer::InvalidDecisionSelection,
      Grape::Exceptions::Validation,
      Grape::Exceptions::ValidationErrors
    ]

    rescue_from *RESCUED_ERRORS do |e|
      WorkflowServer::BaseLogger.info(e)
      Rack::Response.new({error: e.message }.to_json, 400, { "Content-type" => "application/json" }).finish
    end

    mount Api::Workflows
    mount Api::Events
    mount Api::Debug
  end
end
