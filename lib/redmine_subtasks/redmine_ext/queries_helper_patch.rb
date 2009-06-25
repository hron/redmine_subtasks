require 'queries_helper'

module RedmineSubtasks
  module RedmineExt
    module QueriesHelperPatch

      def self.included(base) # :nodoc:    
        base.send(:include, InstanceMethods)     
        base.class_eval do      
          unloadable
          alias_method_chain :column_content, :subtasks
        end
      end

      module InstanceMethods    

        def column_content_with_subtasks(column, issue, query)
          # if column.is_a?(QueryCustomFieldColumn)
          #   cv = issue.custom_values.detect {|v| v.custom_field_id == column.custom_field.id}
          #   show_value(cv)
          # else
          #   value = issue.send(column.name)
          #   if value.is_a?(Date)
          #     format_date(value)
          #   elsif value.is_a?(Time)
          #     format_time(value)
          #   else
          #     case column.name
          #     when :subject
          #       subject_in_tree(issue, value, query)
          #     when :done_ratio
          #       progress_bar(value, :width => '80px')
          #     when :fixed_version
          #       link_to(h(value), { :controller => 'versions', :action => 'show', :id => issue.fixed_version_id })
          #     else
          #       h(value)
          #     end
          #   end
          # end
          if column.name == :subject
            subject_in_tree( issue, issue.send( column.name), query)
          else
            column_content_without_subtasks column, issue
          end
        end
        
        def subject_in_tree(issue, value, query)
          case query.view_options['show_parents']
          when ViewOption::SHOW_PARENTS[:never]
            content_tag('div', subject_text(issue, value), :class=>'issue-subject')
          else
            content_tag('span',
                        content_tag('div',
                                    subject_text(issue, value),
                                    :class=>'issue-subject'),
                        :class=>"issue-subject-level-#{issue.level}")
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
            ( options[:emphasis] ? 'issue-emphasis ' : '' ) +
            "status-#{issue.status.position} priority-#{issue.priority.position} " +
            cycle('odd', 'even') + '">'
          html << '<td class="checkbox">' + check_box_tag( "ids[]", issue.id, false, :id => nil) + '</td>'
          html << '<td>' + link_to( issue.id, :controller => 'issues', :action => 'show', :id => issue) + '</td>'
          query.columns.each do |column|
            html << content_tag( 'td', column_content_with_subtasks(column, issue, query), :class => column.name)
          end
          html << "</tr>"
          html
        end

        def issues_family_content( parent, issues_to_show, query, emphasis_issues)
          html = ""
          html << issue_content( parent, query, :unfiltered => !( issues_to_show.include? parent),
                                 :emphasis => ( emphasis_issues ? emphasis_issues.include?( parent) : false))
          unless  parent.children.empty?
            parent.children.each do |child|
              if issues_to_show.include?( child) || issues_to_show.detect { |i| i.ancestors.include? child }
                html << issues_family_content( child, issues_to_show, query, emphasis_issues)
              end
            end
          end
          html
        end

      end

    end
  end
end

