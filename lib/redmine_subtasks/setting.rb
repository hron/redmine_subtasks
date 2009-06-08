module RedmineSubtasks
  class Setting
    def self.delete_children?
      ::Setting[:plugin_redmine_subtasks][:delete_children].to_i > 0
    end

    def self.subissues_list_columns
      ::Setting[:plugin_redmine_subtasks][:subissues_list_columns]
    end
  end
end
