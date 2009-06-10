class RedmineSubtasksIssuesControllerHooks < Redmine::Hook::Listener

  def controller_issues_new_after_save( context)
    set_issue_parent( context)
  end

  def controller_issues_edit_after_save( context)
    set_issue_parent( context)
  end

  private

  def set_issue_parent( context)
    params = context[:params]
    issue = context[:issue]
    if params[:issue] && !params[:issue][:parent_id].blank? &&
      if params[:issue][:parent_id] == "root"
        issue.move_to_root
      elsif !params[:parent_issue].blank?
        parent_issue = Issue.find( params[:issue][:parent_id])
        issue.move_to_child_of parent_issue
      end
    end
  end
  
end

class RedmineSubtasksIssuesControllerViewHooks < Redmine::Hook::ViewListener
  render_on :view_issues_show_description_bottom, :partial => "issues/subissues_list"
end

    
