require_dependency 'issues_helper' 

module RedmineSubtasks
  module RedmineExt
    module IssuesHelperPatch

      def self.included(base) # :nodoc:    
        base.send(:include, InstanceMethods)     
        base.class_eval do      
          unloadable
        end
      end

      module InstanceMethods    

        def auto_complete_result_parent_issue(candidates, phrase)
          return "" if candidates.empty?
          candidates.map! do |c|
            content_tag("li",
                        highlight( c.to_s, phrase),
                        :id => String( c[:id]))
          end
          content_tag("ul", candidates.uniq)
        end

      end

    end
  end
end


