class AddQueriesViewOptions < ActiveRecord::Migration
  def self.up
    add_column :queries, :view_options, :text
  end

  def self.down
    remove_column :queries, :view_options
  end
end
