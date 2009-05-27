require_dependency 'query'

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
                              [ [ l(:label_view_option_parents_do_not_show), 
                                  Query::VIEW_OPTIONS_SHOW_PARENTS_NEVER ],
                                [ l(:label_view_option_parents_show_always), 
                                  Query::VIEW_OPTIONS_SHOW_PARENTS_ALWAYS ],
                                [ l(:label_view_option_parents_show_and_group), 
                                  Query::VIEW_OPTIONS_SHOW_PARENTS_ORGANIZE_BY_PARENT ] ]) ]
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
            # FIXME: finding in array does not work here...
            # @@available_view_options.find { |vo| vo.name == option }.available_values
            @@available_view_options[0].available_values
          end

          def caption_for_view_option( option)
            # FIXME: finding in array does not work here...
            # @@available_view_options.find { |vo| vo.name == option }.caption
            @@available_view_options[0].caption
          end

        end
      end
      
    end # QueryPatch
  end
end
