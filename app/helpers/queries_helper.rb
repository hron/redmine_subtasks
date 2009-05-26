require_dependency 'queries_helper' 

module QueriesHelper

  def column_content_with_subtasks(column, issue, query)
    if column.is_a?(QueryCustomFieldColumn)
      cv = issue.custom_values.detect {|v| v.custom_field_id == column.custom_field.id}
      show_value(cv)
    else
      value = issue.send(column.name)
      if value.is_a?(Date)
        format_date(value)
      elsif value.is_a?(Time)
        format_time(value)
      else
        case column.name
        when :subject
          subject_in_tree(issue, value, query)
        when :done_ratio
          progress_bar(value, :width => '80px')
        when :fixed_version
          link_to(h(value), { :controller => 'versions', :action => 'show', :id => issue.fixed_version_id })
        else
          h(value)
        end
      end
    end
  end
  alias_method_chain :column_content, :subtasks
  
  def subject_in_tree(issue, value, query)
    RAILS_DEFAULT_LOGGER.info "QUERY: #{query.view_options}"
    case query.view_options['show_parents']
    when Query::VIEW_OPTIONS_SHOW_PARENTS_NEVER
      content_tag('div', subject_text(issue, value), :class=>'issue-subject')
    else
      content_tag('span', content_tag('div', subject_text(issue, value), :class=>'issue-subject'), :class=>"issue-subject-level-#{issue.hierarchical_level}")
    end
  end
  
  def subject_text(issue, value)
    subject_text = link_to(h(value), :controller => 'issues', :action => 'show', :id => issue)
    h((@project.nil? || @project != issue.project) ? "#{issue.project.name} - " : '') + subject_text
  end

  def issue_content(issue, query, options = { })
    html = ""
    html << "<tr id=\"issue-#{issue.id}\" class=\"issue hascontextmenu " +
      ( options[:unfiltered] ? 'issue-unfiltered ' : '') +
      "status-#{issue.status.position} priority-#{issue.priority.position} " +
      cycle('odd', 'even') + '">'
    html << '<td class="checkbox">' + check_box_tag( "ids[]", issue.id, false, :id => nil) + '</td>'
    html << '<td>' + link_to( issue.id, :controller => 'issues', :action => 'show', :id => issue) + '</td>'
    query.columns.each do |column|
      html << content_tag( 'td', column_content(column, issue, query), :class => column.name)
    end
    html << "</tr>"
    html
  end

  def issues_family_content( parent, issues_to_show, query)
    html = ""
    html << issue_content( parent, query, :unfiltered => !( issues_to_show.include? parent))
    unless  parent.children.empty?
      parent.children.each do |child|
        if issues_to_show.include?( child) || issues_to_show.detect { |i| i.ancestors.include? child }
          html << issues_family_content( child, issues_to_show, query)
        end
      end
    end
    html
  end

end

