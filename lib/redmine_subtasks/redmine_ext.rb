module RedmineSubtasks
  module RedmineExt
    Issue.send( :include, IssuePatch)
    Version.send( :include, VersionPatch)
    Query.send( :include, QueryPatch)
    IssuesHelper.send(:include, IssuesHelperPatch)
  end
end
