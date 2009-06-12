class ViewOption
  attr_accessor :name, :available_values
  include Redmine::I18n

  unless const_defined? :SHOW_PARENTS
    SHOW_PARENTS = { :never       => 'do_not_show',
                     :always      => 'show_always',
                     :organize_by => 'organize_by_parent'}.freeze
  end
  
  def initialize( name, available_values)
    self.name = name
    self.available_values = available_values
  end

  def caption
    l("subtasks_label_view_option_#{name}")
  end
end

