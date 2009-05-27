require_dependency 'redmine_subtasks/redmine_ext/issue_patch'
require_dependency 'redmine_subtasks/redmine_ext/query_patch'
require_dependency 'redmine_subtasks/redmine_ext/version_patch'
require_dependency 'redmine_subtasks/redmine_ext/issues_helper_patch'
require_dependency 'redmine_subtasks/redmine_ext/queries_helper_patch'
require_dependency 'redmine_subtasks/redmine_ext/issues_controller_hooks'



class ViewOption
  attr_accessor :name, :available_values
  include Redmine::I18n
  
  def initialize( name, available_values)
    self.name = name
    self.available_values = available_values
  end

  def caption
    l("subtasks_label_view_option_#{name}")
  end
end

class Query < ActiveRecord::Base
  VIEW_OPTIONS_SHOW_PARENTS_NEVER = 'do_not_show'
  VIEW_OPTIONS_SHOW_PARENTS_ALWAYS = 'show_always'
  VIEW_OPTIONS_SHOW_PARENTS_ORGANIZE_BY_PARENT = 'organize_by_parent'
end

module RedmineSubtasks
  module RedmineExt
    Issue.send( :include, IssuePatch)
    Version.send( :include, VersionPatch)
    Query.send( :include, QueryPatch)
    IssuesHelper.send(:include, IssuesHelperPatch)
    QueriesHelper.send(:include, QueriesHelperPatch)
  end
end
