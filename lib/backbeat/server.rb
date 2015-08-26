module Backbeat
  class Server
    extend Logging

    def self.create_workflow(params, user)
      find_workflow(params, user) || Workflow.create!(
        name: params[:workflow_type],
        subject: params[:subject],
        decider: params[:decider],
        user_id: user.id,
        migrated: true
      )
    rescue ActiveRecord::RecordNotUnique => e
      find_workflow(params, user)
    end

    def self.find_workflow(params, user)
      Workflow.where(
        name: params[:workflow_type],
        subject: params[:subject].to_json,
        user_id: user.id
      ).first
    end

    def self.signal(workflow, params)
      raise WorkflowComplete if workflow.complete?
      node = add_node(
        workflow.user,
        workflow,
        params.merge(
          current_server_status: :ready,
          current_client_status: :ready,
          legacy_type: 'decision',
          mode: :blocking
        )
      )
      node
    end

    def self.add_node(user, parent_node, params)
      Node.transaction do
        node = Node.create!(
          mode: params.fetch(:mode, :blocking).to_sym,
          current_server_status: params[:current_server_status] || :pending,
          current_client_status: params[:current_client_status] || :pending,
          name: params[:name],
          fires_at: params[:fires_at] || Time.now - 1.second,
          parent: parent_node,
          workflow_id: parent_node.workflow_id,
          user_id: user.id,
          link_id: params[:link_id]
        )
        options = params[:options] || params
        ClientNodeDetail.create!(
          node: node,
          metadata: options[:metadata] || {},
          data: options[:client_data] || {}
        )
        NodeDetail.create!(
          node: node,
          legacy_type: params[:legacy_type],
          retry_interval: params[:retry_interval],
          retries_remaining: params[:retry]
        )
        node
      end
    end

    def self.resume_workflow(workflow)
      workflow.resume!
      workflow.nodes.where(current_server_status: :paused).each do |node|
        StateManager.transition(node, current_server_status: :started)
        fire_event(Events::StartNode, node)
      end
    end

    def self.fire_event(event, node, scheduler = event.scheduler)
      return if node.deactivated?
      scheduler.call(event, node)
    end
  end
end
