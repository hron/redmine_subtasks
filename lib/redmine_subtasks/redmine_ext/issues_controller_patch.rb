module RedmineSubtasks
  module RedmineExt
    module IssuesControllerPatch
      def self.included(base)
        base.class_eval do
          before_filter :find_issue, :only => [:show, :edit, :reply, :destroy_attachment ]
          before_filter :find_parent_issue, :only => [:add_subissue]
          before_filter :find_optional_parent_issue, :only => [:new]
          before_filter :find_project, :only => [:new, :auto_complete_for_issue_parent, :add_subissue, :update_form, :preview ]
          before_filter :find_optional_project, :only => [:index, :changes, :gantt, :calendar ]
          before_filter :authorize, :except => [:index, :changes, :gantt, :calendar, :preview, :update_form, :context_menu, :auto_complete_for_issue_parent ]

          include ActionView::Helpers::PrototypeHelper
          
          def auto_complete_for_issue_parent
            @phrase = params[:issue_parent]
            @candidates = []

            # If cross project issue relations is allowed we should get
            # candidates from every project
            if Setting.cross_project_issue_relations?
              projects_to_search = nil
            else
              projects_to_search = [ @project ] + @project.active_children
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


          def index
            retrieve_query
            sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
            sort_update({'id' => "#{Issue.table_name}.id"}.merge(@query.available_columns.inject({}) {|h, c| h[c.name.to_s] = c.sortable; h}))
            
            if @query.valid?
              limit = per_page_option
              respond_to do |format|
                format.html { }
                format.atom { }
                format.csv  { limit = Setting.issues_export_limit.to_i }
                format.pdf  { limit = Setting.issues_export_limit.to_i }
              end
              @issue_count = Issue.count(:include => [:status, :project], :conditions => @query.statement)
              @issue_pages = ActionController::Pagination::Paginator.new self, @issue_count, limit, params['page']
              @issues = Issue.find( :all, :order => sort_clause,
                                    :include => [ :assigned_to,
                                                  :status,
                                                  :tracker,
                                                  :project,
                                                  :priority,
                                                  :category,
                                                  :fixed_version ],
                                    :conditions => @query.statement,
                                    :limit  => limit,
                                    :offset => @issue_pages.current.offset)
              
              respond_to do |format|
                format.html { render :template => 'issues/index.rhtml', :layout => !request.xhr? }
                format.atom { render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
                format.csv  { send_data(issues_to_csv(@issues, @project).read, :type => 'text/csv; header=present', :filename => 'export.csv') }
                format.pdf  { send_data(issues_to_pdf(@issues, @project), :type => 'application/pdf', :filename => 'export.pdf') }
              end
            else
              # Send html if the query is not valid
              render(:template => 'issues/index.rhtml', :layout => !request.xhr?)
            end
          rescue ActiveRecord::RecordNotFound
            render_404
          end

          # Add a new issue
          # The new issue will be created from an existing one if copy_from parameter is given
          def new
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

          def add_subissue
            redirect_to :action => 'new', :issue => { :parent_id => @parent_issue }
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

          # Retrieve query from session or build a new query
          def retrieve_query
            if !params[:query_id].blank?
              cond = "project_id IS NULL"
              cond << " OR project_id = #{@project.id}" if @project
              @query = Query.find(params[:query_id], :conditions => cond)
              @query.project = @project
              session[:query] = {:id => @query.id, :project_id => @query.project_id}
              sort_clear
            else
              if params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
                # Give it a name, required to be valid
                @query = Query.new(:name => "_")
                @query.project = @project
                if params[:fields] and params[:fields].is_a? Array
                  params[:fields].each do |field|
                    @query.add_filter(field, params[:operators][field], params[:values][field])
                  end
                else
                  @query.available_filters.keys.each do |field|
                    @query.add_short_filter(field, params[field]) if params[field]
                  end
                end
                if params[:view_options] and params[:view_options].is_a? Hash
                  params[:view_options].each_pair do |name, value|
                    @query.set_view_option( name, value)
                  end
                end
                session[:query] = {
                  :project_id => @query.project_id,
                  :filters => @query.filters,
                  :view_options => @query.view_options
                }
              else
                @query = Query.find_by_id(session[:query][:id]) if session[:query][:id]
                @query ||= Query.new(:name => "_",
                                     :project => @project,
                                     :filters => session[:query][:filters],
                                     :view_options => session[:query][:view_options])
                @query.project = @project
              end
            end
          end
        end
      end
    end
  end
end
