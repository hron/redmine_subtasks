module RedmineSubtasks
  class Setting
    def self.delete_children?
      ::Setting[:plugin_redmine_subtasks][:delete_children].to_i > 0
    end
  end
end
