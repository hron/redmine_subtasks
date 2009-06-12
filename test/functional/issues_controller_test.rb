require File.dirname(__FILE__) + '/../test_helper'
require 'issues_controller'

class IssuesController; def rescue_action(e) raise e end; end

class IssuesControllerTest < Test::Unit::TestCase

  fixtures( :projects,
            :users,
            :roles,
            :members,
            :member_roles,
            :issues,
            :issue_statuses,
            :versions,
            :trackers,
            :projects_trackers,
            :issue_categories,
            :enabled_modules,
            :enumerations,
            :attachments,
            :workflows,
            :custom_fields,
            :custom_values,
            :custom_fields_trackers,
            :time_entries,
            :journals,
            :journal_details)
  
  def setup
    @controller = IssuesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
  end

  def test_new_child_issue
    child_issue_subject = 'This is the test_new child issue'
    parent_issue = issues( :issues_root)
    @request.session[:user_id] = 2

    post( :new, :project_id => 1,
          :parent_issue => parent_issue,
          :issue => {:tracker_id => 3,
            :subject => child_issue_subject,
            :description => 'This is the description',
            :priority_id => 5,
            :parent_id => parent_issue.id,
            :estimated_hours => '',
            :custom_field_values => {'2' => 'Value for field 2'}})
    child = Issue.find_by_subject( child_issue_subject)

    assert_redirected_to "issues/#{child.id}"
    assert( child.parent == parent_issue,
            "New child has Issue id=#{child.parent} as parent, not id=#{parent_issue}")
  end

  def test_edit_issue_set_parent
    parent_issue = issues( :issues_root)
    moving_issue = issues( :issues_subchild003)
    @request.session[:user_id] = 2

    post( :edit,
          :id => moving_issue.id,
          :project_id => 1,
          :parent_issue => parent_issue,
          :issue => {
            :parent_id => parent_issue.id
          })
    assert_redirected_to :action => 'show', :id => moving_issue.id
    assert moving_issue.reload.parent == parent_issue
  end

  def test_move_child_to_root
    parent = issues( :issues_root)
    child = issues( :issues_child001)

    post( :edit,
          :id => child.id,
          :project_id => 1,
          :issue => {
            :parent_id => "root",
          })
    assert_redirected_to :action => 'show', :id => child.id
    assert child.reload.root?
  end

  def test_add_subissue_should_redirect_to_action_new
    @request.session[:user_id] = 2
    get( :add_subissue, :project_id => 1,
         :issue => {
           :tracker_id      => 3,
           :priority_id     => 5,
           :subject         => "test_add_subissue",
           :description     => "test_add_subissue",
           :estimated_hours => '' },
         :parent_issue_id => 1)
    assert_redirected_to :action => "new"
  end

  def test_add_subissue_with_invalid_parent_id_should_render_404
    @request.session[:user_id] = 2
    get( :add_subissue, :project_id => 1,
         :issue => {
           :tracker_id => 3,
           :subject => "test_add_subissue",
           :description => "test_add_subissue",
           :priority_id => 5,
           :estimated_hours => ''},
         :parent_issue_id => 'invalid_id')
    assert_template 'common/404', :status => 404
  end

  def test_index_view_option_always_show_parents
    @request.session[:user_id] = 2
    get( :index,
         :project_id => 1,
         :set_filter => 1,
         :view_options => { :show_parents => "show_always"})
    assert_response :success
    assert_tag( :tag => 'span', 
                :attributes => { :class => 'issue-subject-level-2'},
                :content => /subchild001/)
    assert_tag( :tag => 'span', 
                :attributes => { :class => 'issue-subject-level-1'},
                :content => /child001/)
    assert_tag( :tag => 'span', 
                :attributes => { :class => 'issue-subject-level-0'},
                :content => /root/)
  end

end
