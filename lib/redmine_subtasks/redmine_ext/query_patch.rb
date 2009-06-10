
module RedmineSubtasks
  module RedmineExt
    module QueryPatch

      def self.included(base)
        base.class_eval do

          unloadable
          
          include Redmine::I18n
          
          serialize :view_options

          @@available_view_options =
            [ ViewOption.new( 'show_parents',
                              [ [ l(:subtasks_label_view_option_parents_do_not_show), 
                                  ViewOption::SHOW_PARENTS[:never] ],
                                [ l(:subtasks_label_view_option_parents_show_always), 
                                  ViewOption::SHOW_PARENTS[:always] ],
                                [ l(:subtasks_label_view_option_parents_show_and_group), 
                                  ViewOption::SHOW_PARENTS[:organize_by]]])
            ]
          cattr_reader :available_view_options

          def initialize(attributes = nil)
            super attributes
            self.filters ||= { 'status_id' => {:operator => "o", :values => [""]} }
            self.view_options ||=  { 'show_parents' => 'do_not_show' }
          end
          
          def set_view_option( option, value)
            self.view_options[option] = value
          end

          def values_for_view_option( option)
            @@available_view_options.find { |vo| vo.name == option }.available_values
          end

          def caption_for_view_option( option)
            @@available_view_options.find { |vo| vo.name == option }.caption
          end

        end
      end
      
    end # QueryPatch
  end
end
