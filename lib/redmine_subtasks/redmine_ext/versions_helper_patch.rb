require_dependency 'versions_helper' 

module RedmineSubtasks
  module RedmineExt
    module VersionsHelperPatch

      def self.included(base) # :nodoc:    
        base.send(:include, InstanceMethods)     
        base.class_eval do      
          unloadable
        end
      end

      module InstanceMethods    

        def render_list_of_related_issues( issues, version, current_level = 0)
          issues_on_current_level = issues.select { |i| i.level == current_level }
          issues -= issues_on_current_level
          content_tag( 'ul') do
            html = ''
            issues_on_current_level.each do |issue|
              opts_for_issue_li = { }
              if !issue.fixed_version or issue.fixed_version != version
                opts_for_issue_li[:class] = 'issue-unfiltered'
              end
              html << content_tag( 'li', opts_for_issue_li) do
                opts = { }
                if issue.done_ratio == 100
                  opts[:style] = 'font-weight: bold'
                end
                link_to_issue(issue, opts)  + ": " + h(issue.subject)
              end
              children_to_print = issues & issue.children
              children_to_print += issues.select { |i| i.level >= current_level + 2}
              unless children_to_print.empty?
                html << render_list_of_related_issues( children_to_print, version, current_level + 1)
              end
            end
            html
          end
        end

      end # InstanceMethods

    end
  end
end

    
