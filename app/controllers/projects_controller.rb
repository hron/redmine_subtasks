require_dependency 'redmine_subtasks/redmine_ext'
require_dependency 'projects_controller'

class ProjectsController < ApplicationController

  unloadable

  helper :versions
  include VersionsHelper
  
end
