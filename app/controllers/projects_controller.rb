require_dependency 'projects_controller'

class ProjectsController < ApplicationController

  unloadable

  helper :versions
  include VersionsHelper
  
end
