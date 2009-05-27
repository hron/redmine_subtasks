require_dependency 'redmine_subtasks/redmine_ext'
require_dependency 'issues_controller'

class IssuesController < ApplicationController

  unloadable
  
  prepend_before_filter :redmine_ext
  
  skip_before_filter :authorize, :only => [ :add_subissue,
                                            :auto_complete_for_issue_parent]

  before_filter :find_parent_issue, :only => [:add_subissue]
  before_filter :find_optional_parent_issue, :only => [:new]
  before_filter :find_project, :only => [ :add_subissue,
                                          :auto_complete_for_issue_parent ]

  include ActionView::Helpers::PrototypeHelper
  
  def add_subissue
    redirect_to :action => 'new',
                :issue => { :parent_id => @parent_issue.id }
  end

  def auto_complete_for_issue_parent
    @phrase = params[:issue_parent]
    @candidates = []

    # If cross project issue relations is allowed we should get
    # candidates from every project
    if Setting.cross_project_issue_relations?
      projects_to_search = nil
    else
      projects_to_search = [ @project ] + @project.children
    end

    # Try to find issue by id.
    if @phrase.match(/^#?(\d+)$/)
      if Setting.cross_project_issue_relations?
        issue = Issue.find_by_id( $1)
      else
        issue = Issue.find_by_id_and_project_id( $1, projects_to_search.collect { |i| i.id})
      end
      @candidates = [ issue ] if issue
    end

    # If finding by id is fail, try to find by searching in subject
    # and description.
    if @candidates.empty?
      # extract tokens from the question
      # eg. hello "bye bye" => ["hello", "bye bye"]
      tokens = @phrase.scan(%r{((\s|^)"[\s\w]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
      # tokens must be at least 3 character long
      tokens = tokens.uniq.select {|w| w.length > 2 }
      like_tokens = tokens.collect {|w| "%#{w.downcase}%"}      

      @candidates, count = Issue.search( like_tokens, projects_to_search, :before => true)
    end

    render :inline => "<%= auto_complete_result_parent_issue( @candidates, @phrase) %>"
  end



  private

  def find_parent_issue
    @parent_issue = Issue.find( params[:parent_issue_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_optional_parent_issue
    if params[:issue] && !params[:issue][:parent_id].blank?
      @parent_issue = Issue.find( params[:issue][:parent_id])
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def redmine_ext
    self.class_eval do

      def new_with_subtasks
        @issue = Issue.new
        @issue.copy_from(params[:copy_from]) if params[:copy_from]
        @issue.project = @project
        # Tracker must be set before custom field values
        @issue.tracker ||= @project.trackers.find((params[:issue] && params[:issue][:tracker_id]) || params[:tracker_id] || :first)
        if @issue.tracker.nil?
          render_error 'No tracker is associated to this project. Please check the Project settings.'
          return
        end
        if params[:issue].is_a?(Hash)
          @issue.attributes = params[:issue]
          @issue.watcher_user_ids = params[:issue]['watcher_user_ids'] if User.current.allowed_to?(:add_issue_watchers, @project)
        end
        @issue.author = User.current
        
        default_status = IssueStatus.default
        unless default_status
          render_error 'No default issue status is defined. Please check your configuration (Go to "Administration -> Issue statuses").'
          return
        end    
        @issue.status = default_status
        @allowed_statuses = ([default_status] + default_status.find_new_statuses_allowed_to(User.current.roles_for_project(@project), @issue.tracker)).uniq

        if request.get? || request.xhr?
          @issue.start_date ||= Date.today
        else
          requested_status = IssueStatus.find_by_id(params[:issue][:status_id])
          # Check that the user is allowed to apply the requested status
          @issue.status = (@allowed_statuses.include? requested_status) ? requested_status : default_status
          if @issue.save
            attach_files(@issue, params[:attachments])
            flash[:notice] = l(:notice_successful_create)
            call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
            @issue.move_to_child_of @parent_issue if @parent_issue
            redirect_to(params[:continue] ? { :action => 'new', :tracker_id => @issue.tracker } :
                        { :action => 'show', :id => @issue })
            return
          end		
        end	
        @priorities = Enumeration.priorities
        render :layout => !request.xhr?
      end
      alias_method_chain :new, :subtasks

      def retrieve_query_with_subtasks
        retrieve_query_without_subtasks
        if params[:query_id].blank?
          if params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
            if params[:view_options] and params[:view_options].is_a? Hash
              params[:view_options].each_pair do |name, value|
                @query.set_view_option( name, value)
              end
            end
            session[:query][:view_options] = @query.view_options
          else
            params[:view_options].each_pair do |name, value|
              @query.set_view_option( name, value)
            end
          end
        end
      end
      alias_method_chain :retrieve_query, :subtasks
    end
  end

end
