class AddIssuesParentIdLftAndRgt < ActiveRecord::Migration

  def self.up
    add_column :issues, :parent_id, :integer, :default => nil
    add_column :issues, :lft, :integer
    add_column :issues, :rgt, :integer
  end

  def self.down
    remove_column :issues, :parent_id
    remove_column :issues, :lft
    remove_column :issues, :rgt
  end
end
