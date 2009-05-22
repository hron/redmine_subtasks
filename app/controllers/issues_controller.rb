class IssuesController < ApplicationController
  before_filter :invoke_redmine_subtasks_patches
  unloadable 
  protected
  def invoke_redmine_subtasks_patches
    RedmineSubtasks::RedmineExt
    IssuesController.send( :include, RedmineSubtasks::RedmineExt::IssuesControllerPatch)
  end
end
