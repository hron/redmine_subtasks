module RedmineSubtasks
  module RedmineExt
    module QueryPatch

      VIEW_OPTIONS_SHOW_PARENTS_NEVER = 'do_not_show'
      VIEW_OPTIONS_SHOW_PARENTS_ALWAYS = 'show_always'
      VIEW_OPTIONS_SHOW_PARENTS_ORGANIZE_BY_PARENT = 'organize_by_parent'

      class ViewOption
        attr_accessor :name, :available_values
        include Redmine::I18n
        
        def initialize( name, available_values)
          self.name = name
          self.available_values = available_values
        end

        def caption
          l("label_view_option_#{name}")
        end
      end

      def self.included(base)
        base.class_eval do

          include Redmine::I18n
          
          serialize :view_options

          @@available_view_options =
            [ ViewOption.new( 'show_parents',
                              [ [ l(:label_view_option_parents_do_not_show), 
                                  VIEW_OPTIONS_SHOW_PARENTS_NEVER ],
                                [ l(:label_view_option_parents_show_always), 
                                  VIEW_OPTIONS_SHOW_PARENTS_ALWAYS ],
                                [ l(:label_view_option_parents_show_and_group), 
                                  VIEW_OPTIONS_SHOW_PARENTS_ORGANIZE_BY_PARENT ] ]) ]
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
