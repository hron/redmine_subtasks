class AddDefaultValueOfViewOptoinsQueries < ActiveRecord::Migration
  def self.up
    Query.find(:all).each do |q|
      q.view_options ||= { 'show_parents' => 'do_not_show' }
      q.save!
    end
  end

  def self.down
  end
end
