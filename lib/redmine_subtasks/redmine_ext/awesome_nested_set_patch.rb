require 'awesome_nested_set'

CollectiveIdea::Acts::NestedSet::InstanceMethods.class_eval do

  def move_to_left_of(node)
    nested_set_move_to node, :left
  end

  def move_to_right_of(node)
    nested_set_move_to node, :right
  end

  def move_to_child_of(node)
    nested_set_move_to node, :child
  end
  
  def move_to_root
    nested_set_move_to nil, :root
  end

  protected

  alias_method :nested_set_move_to, :move_to

end


