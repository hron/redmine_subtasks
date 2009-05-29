class IssuesRebuild < ActiveRecord::Migration

  # IssueRelation::TYPE_PARENTS was deleted
  TYPE_PARENTS = "parents"
  
  def self.up

    # detect if we migrating from #443 issue patch to using this
    # plugin
    patch_for_issue443 = IssueRelation.find_by_relation_type( TYPE_PARENTS)

    if patch_for_issue443
      say_with_time "fixing invalid issues" do
        Issue.find( :all).each do |issue|
          if !issue.valid? && issue.errors.on( :due_date)
            issue.due_date = issue.start_date
            issue.save!
          end
        end
      end
    end

    say_with_time "rebuilding left & right indexes" do
      Issue.rebuild!
    end

    if patch_for_issue443
      say_with_time(
                    "converting subissues for using parent_id instead of IssueRelation") do 
        IssueRelation.find_all_by_relation_type( TYPE_PARENTS).each do |rel|
          rel.issue_from.move_to_child_of rel.issue_to.id
          rel.delete
        end
      end
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
