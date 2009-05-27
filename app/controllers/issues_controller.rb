require_dependency 'redmine_subtasks/redmine_ext'
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
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def redmine_ext
    self.class_eval do

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
            if session[:query][:view_options]
              session[:query][:view_options].each_pair do |name, value|
                @query.set_view_option( name, value)
              end
            end
          end
        end
      end
      alias_method_chain :retrieve_query, :subtasks

    end
  end

end
