require_dependency 'issues_controller'

class IssuesController < ApplicationController

  unloadable
  
  prepend_before_filter :redmine_ext

  skip_before_filter :authorize, :only => [ :add_subissue,
                                            :auto_complete_for_issue_parent]
  before_filter :find_parent_issue, :only => [:add_subissue]
  before_filter :find_optional_parent_issue, :only => [:new]
  prepend_before_filter :find_project, :only => [ :add_subissue,
                                                  :new,
                                                  :update_form,
                                                  :preview,
                                                  :auto_complete_for_issue_parent ]
  before_filter :authorize, :except => [ :index,
                                         :changes,
                                         :gantt,
                                         :calendar,
                                         :preview,
                                         :update_form,
                                         :context_menu]
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
  end

  def retrieve_query_with_subtasks
    retrieve_query_without_subtasks
    if params[:query_id].blank?
      if params[:set_filter]
        if params[:view_options] and params[:view_options].is_a? Hash
          params[:view_options].each_pair do |name, value|
            @query.set_view_option( name, value)
          end
        end
        session[:query][:view_options] = @query.view_options
      else
        if session[:query][:view_options]
          session[:query][:view_options].each_pair do |name, value|
            @query.set_view_option( name, value)
          end
        end
      end
    end
  end

  def find_issue_with_subtasks
    find_issue_without_subtasks
    @parent_issue = @issue.parent if @issue
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def show_with_subtasks
    retrieve_query
    @query.project = @project
		@query.set_view_option( 'show_parents',
                            ViewOption::SHOW_PARENTS[:organize_by])
    @query.column_names = RedmineSubtasks::Setting.subissues_list_columns
    sort_init( @query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update({'id' => "#{Issue.table_name}.id"}.merge( @query.available_columns.inject({}) { |h, c| h[c.name.to_s] = c.sortable; h}))

    @journals = @issue.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
    @changesets = @issue.changesets
    @changesets.reverse! if User.current.wants_comments_in_reverse_order?
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @priorities = IssuePriority.all
    @time_entry = TimeEntry.new
    respond_to do |format|
      format.html { render :template => 'issues/show.rhtml',
                           :layout => !request.xhr? }
      format.atom { render :action => 'changes',
                           :layout => false, 
                           :content_type => 'application/atom+xml' }
      format.pdf  { send_data(issue_to_pdf(@issue), 
                              :type => 'application/pdf', 
                              :filename => "#{@project.identifier}-#{@issue.id}.pdf") }
    end
  end

  def redmine_ext
    self.class_eval do

      [ :retrieve_query, :find_issue, :show ].each do |method|
        alias_method_chain method, :subtasks
      end
    end
  end

end
