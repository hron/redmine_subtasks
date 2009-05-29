class AddQueriesViewOptions < ActiveRecord::Migration

  # IssueRelation::TYPE_PARENTS was deleted
  TYPE_PARENTS = "parents"

  def self.up
    # skip this migration if you *do* have installed #443 patch
    # previously
    return if IssueRelation.find_by_relation_type( TYPE_PARENTS)
    
    add_column :queries, :view_options, :text
  end

  def self.down
    remove_column :queries, :view_options
  end
end
