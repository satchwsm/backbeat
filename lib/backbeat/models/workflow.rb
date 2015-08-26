require 'backbeat/models/child_queries'

module Backbeat
  class Workflow < ActiveRecord::Base
    belongs_to :user
    has_many :nodes
    serialize :subject, JSON

    validates :subject, presence: true
    validates :decider, presence: true
    validates :user_id, presence: true

    include ChildQueries

    def parent
      nil
    end

    def children
      nodes.where(parent_id: nil)
    end

    def workflow_id
      id
    end

    def deactivated?
      false
    end

    def complete!
      update_attributes(complete: true)
    end

    def pause!
      update_attributes(paused: true)
    end

    def resume!
      update_attributes(paused: false)
    end

    def destroy
      children.map(&:destroy)
      super
    end

    def link_complete?
      true
    end
  end
end
