require 'redmine'
require 'redmine_subtasks/redmine_ext'

RAILS_DEFAULT_LOGGER.info 'Starting Subtasks plugin for RedMine'

Redmine::Plugin.register :redmine_subtasks do
  name 'Subtasks plugin'
  author 'Aleksei Gusev'
  description 'This is plugin for Redmine for adding subtasks functionality.'
  version '0.0.1'

  # remapping permissions
  Redmine::AccessControl.permissions.delete_if do |p|
    p.name == :manage_issue_relations
  end
  project_module :issue_tracking do |map|
    map.permission :manage_issue_relations, {
      :issue_relations => [:new, :destroy],
      :issues => [:add_subissue]
    }
  end

end

