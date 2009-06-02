class RedmineSubtasksIssuesControllerHooks < Redmine::Hook::Listener
  def controller_issues_new_after_save( context)
    params = context[:params]
    issue = context[:issue]
    if params[:issue] && !params[:issue][:parent_id].blank?
      parent_issue = Issue.find( params[:issue][:parent_id])
      issue.move_to_child_of parent_issue 
    end
  end
end

class RedmineSubtasksIssuesControllerViewHooks < Redmine::Hook::ViewListener
  render_on :view_issues_show_description_bottom, :partial => "issues/subissues_list"
end

    
