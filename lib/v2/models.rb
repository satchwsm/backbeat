class ActiveRecord::Base
  before_create do
    self.id = UUIDTools::UUID.random_create.to_s if self.id.nil?
  end
end
require_relative 'models/user'
require_relative 'models/node'
require_relative 'models/node_detail'
require_relative 'models/client_node_detail'
require_relative 'models/status_change'
require_relative 'models/workflow'