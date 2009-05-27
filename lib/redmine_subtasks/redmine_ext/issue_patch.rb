require 'redmine_subtasks/redmine_ext/awesome_nested_set_patch'
require_dependency 'issue'

module RedmineSubtasks
  module RedmineExt
    module IssuePatch

      def self.included(base)
        base.class_eval do
          acts_as_nested_set

          after_save :do_subtasks_hooks
          def do_subtasks_hooks
            if parent
              # Set default status of parent if new status opened the issue.
              if !status.is_closed? && parent.status.is_closed?
                parent.update_attribute :status, IssueStatus.default
              end

              # Set 'Target version' of parent if one was set on one of the
              # children issue and parent have no 'Target version'. Do the same
              # if 'Target version of the parent issue lower (by the release
              # date or by the version number).
              if parent.fixed_version.nil? && fixed_version or
                  ( parent.fixed_version && fixed_version and
                    parent.fixed_version.project == fixed_version.project and
                    parent.fixed_version < fixed_version )
                parent.update_attribute :fixed_version, fixed_version
              end
            end
          end

          validate :subtasks_validation
          def subtasks_validation
            unless children.empty?
              if IssueStatus.find_by_id( @attributes['status_id']).is_closed? &&
                  children.detect { |i| !i.closed? }
                errors.add( :status,
                            "Can't close parent issue " +
                            "while one of the children is still open.")
              end

              children_max_fixed_version = children.select { |i| i.fixed_version } .max { |a,b| a.fixed_version <=> b.fixed_version }
              if @attributes['fixed_version_id'] && children_max_fixed_version
                if Version.find_by_id( @attributes['fixed_version_id']) < children_max_fixed_version.fixed_version
                  errors.add :fixed_version, "Can't set target version of parent issue lower than any of the children."
                end
              end
            end
          end
          
          def after_save
            # Reload is needed in order to get the right status
            reload

            # Update start/due dates of following issues
            relations_from.each(&:set_issue_to_dates)

            if parent
              # Set default status of parent if new status opened the issue.
              if !status.is_closed? && parent.status.is_closed?
                parent.update_attribute :status, IssueStatus.default
              end

              # Set 'Target version' of parent if one was set on one of the
              # children issue and parent have no 'Target version'. Do the same
              # if 'Target version of the parent issue lower (by the release
              # date or by the version number).
              if parent.fixed_version.nil? && fixed_version or
                  ( parent.fixed_version && fixed_version and
                    parent.fixed_version.project == fixed_version.project and
                    parent.fixed_version < fixed_version )
                parent.update_attribute :fixed_version, fixed_version
              end
            end

            # If target version is set, but "Due to" date is not, set it as
            # the same as the date of target version.
            if due_date.nil? && fixed_version && fixed_version.due_date
              self.update_attribute :due_date, fixed_version.due_date
            end

            # Close duplicates if the issue was closed
            if @issue_before_change && !@issue_before_change.closed? && self.closed?
              duplicates.each do |duplicate|
                # Reload is need in case the duplicate was updated by a previous duplicate
                duplicate.reload
                # Don't re-close it if it's already closed
                next if duplicate.closed?
                # Same user and notes
                duplicate.init_journal(@current_journal.user, @current_journal.notes)
                duplicate.update_attribute :status, self.status
              end
            end
          end

          # Moves/copies an issue to a new project and tracker
          # Returns the moved/copied issue on success, false on failure
          def move_to(new_project, new_tracker = nil, options = {})
            options ||= {}
            issue = if options[:copy]
                      Issue.new( self.attributes.reject { |k,v| k == 'parent_id' })
                    else
                      self
                    end
            transaction do
              if new_project && issue.project_id != new_project.id
                unless Setting.cross_project_issue_relations?
                  # delete issue relations
                  issue.relations_from.clear
                  issue.relations_to.clear

                  issue.children.each(&:move_to_root) unless options[:copy]
                end
                # issue is moved to another project
                # reassign to the category with same name if any
                new_category = issue.category.nil? ? nil : new_project.issue_categories.find_by_name(issue.category.name)
                issue.category = new_category
                issue.fixed_version = nil
                issue.project = new_project
              end
              if new_tracker
                issue.tracker = new_tracker
              end
              if options[:copy]
                issue.custom_field_values = self.custom_field_values.inject({}) {|h,v| h[v.custom_field_id] = v.value; h}
                issue.status = self.status
              end
              if issue.save
                unless options[:copy]
                  # Manually update project_id on related time entries
                  TimeEntry.update_all("project_id = #{new_project.id}", {:issue_id => id})
                end
                if new_project && issue.project_id != new_project.id &&
                    !Setting.cross_project_issue_relations?
                  issue.move_to_root
                end
              else
                Issue.connection.rollback_db_transaction
                return false
              end
            end
            return issue
          end
          
          def done_ratio
            if children?
              @total_planned_days ||= 0
              @total_actual_days ||= 0
              children.each do |child| # from every subtask get the total number of days and the number of days already "worked"
                planned_days = child.duration1
                actual_days = child.done_ratio ?  (planned_days * child.done_ratio / 100).floor : 0
                @total_planned_days += planned_days
                @total_actual_days += actual_days
              end
              @total_done_ratio = @total_planned_days != 0 ? (@total_actual_days * 100 / @total_planned_days).floor : 0
            else
              read_attribute(:done_ratio)
            end
          end

          def estimated_hours
            if children?
              is_set = false
              children.each do |child|
                if child.estimated_hours
                  if is_set
                    @est_hours += child.estimated_hours
                  else
                    @est_hours = child.estimated_hours
                    is_set = true
                  end
                end     
              end
              @est_hours
            else
              read_attribute(:estimated_hours)
            end
          end

          def due_date
            if children?
              children_date = children.find_all { |i| i.due_date } 
              unless children_date.empty?
                children_date.sort { |a,b| a.due_date <=> b.due_date} .max
              else
                read_attribute(:due_date)
              end
            else
              read_attribute(:due_date)
            end
          end  
          
          def children?
            children != []
          end
          
          #First level tasks have hierarchical level = 1 and so on
          def hierarchical_level(issue=self)
            1 + level
          end
          
          # FIXME: remove this method.
          def self.find_with_parents( *args)
            issues = find( *args)
            return [] if issues.empty?
            issues.each do |i|
              while not i.root?
                issues += [ i.parent ]
                i = i.parent
              end
            end
            issues.uniq
          end

          protected

          def duration1
            (start_date && due_date) ? (due_date - start_date + 1) : 0
          end

        end
      end

    end
  end
end
