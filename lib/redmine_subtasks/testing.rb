require 'test/unit'

require 'tmpdir'
require 'fileutils'

module RedmineSubtasks::Testing
  mattr_accessor :temporary_fixtures_directory
  self.temporary_fixtures_directory =
    FileUtils.mkdir_p( File.join( Dir.tmpdir, "rails_fixtures"))

  def self.override_core_fixtures
    plugin = Engines.plugins[:redmine_subtasks]
    Engines.mirror_files_from(File.join(RAILS_ROOT, "test", "fixtures"),
                              self.temporary_fixtures_directory)
    plugin_fixtures_directory =  File.join( plugin.directory, "test", "fixtures")
    if File.directory?(plugin_fixtures_directory)
      Engines.mirror_files_from( plugin_fixtures_directory,
                                 self.temporary_fixtures_directory)
    end
  end

  def self.set_fixture_path
    Test::Unit::TestCase.fixture_path = self.temporary_fixtures_directory
    $LOAD_PATH.unshift self.temporary_fixtures_directory
  end
end
