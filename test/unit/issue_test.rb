require File.dirname(__FILE__) + '/../test_helper'

class IssueTest < Test::Unit::TestCase
  fixtures( :projects, :users, :members,
            :trackers, :projects_trackers,
            :issue_statuses, :issue_categories,
            :enumerations,
            :issues,
            :custom_fields,
            :custom_fields_projects,
            :custom_fields_trackers,
            :custom_values,
            :time_entries,
            :versions)

  def test_should_update_target_version_of_parent_issue
    create_family_of_issues 'Target version of parent updates test'

    version_0_1 = Version.find( versions( :versions_001).id)
    version_1_0 = Version.find( versions( :versions_002).id)
    
    # set target version for child
    @issue2.fixed_version = version_0_1
    assert @issue2.save
    assert @issue1.reload.fixed_version == @issue2.fixed_version

    # set target version for child of child larger than target version
    # of child. so, target version of parents should be updated.
    @issue3.fixed_version = version_1_0
    assert @issue3.save
    assert @issue1.reload.fixed_version == @issue3.fixed_version
  end

  def test_should_not_allowed_close_parent_issue_while_one_of_children_open
    create_family_of_issues 'Closing parent issue when some children is open test.'

    closed_status = issue_statuses( :issue_statuses_005)
    @issue3.status = closed_status
    assert @issue3.save

    assert_raise ActiveRecord::RecordInvalid do
      @issue1.reload.status = closed_status
      @issue1.save!
    end
    
  end

  def test_should_change_status_of_parent_when_some_children_is_open
    create_family_of_issues 'Changing status of parent from closed to open when some of children is open.'

    open_status   = issue_statuses( :issue_statuses_001)
    closed_status = issue_statuses( :issue_statuses_005)

    @issue3.status = closed_status
    @issue2.status = closed_status
    @issue1.status = closed_status
    assert @issue3.save
    assert @issue2.save
    assert @issue1.save
    assert @issue1.reload.closed?
    assert @issue2.reload.closed?
    assert @issue3.reload.closed?

    # set status of children to open status. this should update status
    # of parent and set it to open state.
    @issue2.status = open_status
    assert @issue2.save
    assert !@issue2.reload.closed?
    assert !@issue1.reload.closed?
  end

  def test_should_update_targetversion_of_parent_if_children_have_bigger_targetversion
    create_family_of_issues 'Update target version of parent if children have bigger target version.'

    # set parent version to 1.
    @issue1.fixed_version = versions( :versions_001)
    assert @issue1.save
    assert @issue1.reload.fixed_version == versions( :versions_001)

    # set children to version higher that parent.
    @issue2.fixed_version = versions( :versions_002)
    assert @issue2.save
    assert @issue1.reload.fixed_version == versions( :versions_002)
  end

  def test_should_set_target_version_of_parent_if_children_have_a_target_version
    create_family_of_issues 'Update target version of parent if children have a target version.'

    @issue2.fixed_version = versions( :versions_001)
    assert @issue2.save
    assert @issue2.reload.fixed_version == versions( :versions_001)
    assert @issue1.reload.fixed_version == @issue2.fixed_version
  end

  def test_should_not_allow_to_set_targetversion_of_parent_lower_than_any_of_the_children
    create_family_of_issues 'Not allowing to set target version of parent lower than any of the children.'

    [ @issue1, @issue2, @issue3 ].each do |issue|
      issue.update_attribute :fixed_version, versions( :versions_002)
    end

    assert_raise ActiveRecord::RecordInvalid do
      @issue1.fixed_version = versions( :versions_001)
      @issue1.save!
    end
  end

  def test_should_not_set_target_version_of_parent_if_child_on_another_project
    create_family_of_issues 'Should not set target version of parnet if child on another project.'

    @issue2.fixed_version = versions( :versions_001)
    assert @issue2.save
    assert @issue1.reload.fixed_version == versions( :versions_001)

    online_store = projects( :projects_002)
    assert @issue2.move_to( online_store)
    @issue2.reload.fixed_version = versions( :onlinestore_1_0)
    assert @issue2.save
    assert @issue1.reload.fixed_version == versions( :versions_001)
    assert @issue2.reload.fixed_version == versions( :onlinestore_1_0)
  end

  def test_should_update_due_to_date_if_target_version_is_set_but_due_to_is_not
    @issue = Issue.new( :project_id => 1, :tracker_id => 1,
                        :author_id => 1, :status_id => 1,
                        :priority => IssuePriority.priorities.first,
                        :subject => 'issue for test hook which set due_to when sets target version.',
                        :description => 'issue for test hook which set due_to when sets target version.')

    assert @issue.save!
    assert @issue.reload.due_date == nil
    @issue.fixed_version = versions( :versions_001)
    assert @issue.save!
    assert @issue.reload.due_date == @issue.reload.fixed_version.due_date
  end

  def test_settings_delete_children_on
    with_settings :plugin_redmine_subtasks => { :delete_children => "1" } do
      @root = issues( :issues_root)
      children_before_delete = @root.children.clone
      assert @root.destroy, "failed to destroy parent issue"
      assert_raise ActiveRecord::RecordNotFound do
        children_before_delete.each( &:reload)
      end
    end
  end
  
  def test_settings_delete_children_off
    with_settings :plugin_redmine_subtasks => { :delete_children => "0" } do
      @root = issues( :issues_root)
      children_before_delete = @root.children.clone
      assert @root.destroy, "failed to destroy parent issue"
      assert_nothing_raised do
        children_before_delete.each( &:reload)
      end
    end
  end

  def test_should_not_change_target_version_if_children_from_another_project
    with_settings :cross_project_issue_relations => true do
      @root = issues( :issues_root)
      @issue_another_project = issues( :issue_leaf_from_another_project)

      older_version = versions( :versions_001)
      newer_version = versions( :onlinestore_1_0)
      @root.update_attribute :fixed_version,  older_version
      @issue_another_project.move_to_child_of @root
      assert @root.reload.fixed_version == older_version
    end
  end
  
  
  private

  # TODO: rewrite all test used this method to using fixtures
  # instead of creating families of issues.
  def create_family_of_issues( subject)
    # Create 3 issues
    @issue1 = Issue.new( :project_id  => 1, :tracker_id => 1,
                         :author_id   => 1, :status_id => 1,
                         :priority    => IssuePriority.priorities.first,
                         :subject     => subject,
                         :description => subject)
    assert @issue1.save
    @issue2 = @issue1.clone
    assert @issue2.save
    @issue3 = @issue1.clone
    assert @issue3.save

    # 2 is a child of 1 
    @issue2.move_to_child_of @issue1
    
    # And 3 is a child of 2
    @issue3.move_to_child_of @issue2
    
    @issue1.reload
    @issue2.reload
    @issue3.reload

    assert @issue2.parent == @issue1
    assert @issue2.children.include?( @issue3)
  end

end
