require_dependency 'version'

module RedmineSubtasks
  module RedmineExt
    module VersionPatch

      def self.included(base)
        base.class_eval do
          include Comparable
        end
      end
    end
  end
end


