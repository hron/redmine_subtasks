namespace :test do
  desc "Override specific fixtures from the core with provided by plugin."
  task :override_core_fixtures => :environment do
    RedmineSubtasks::Testing.override_core_fixtures
  end

  [ "test:plugins" ].each do |t|
    Rake::Task[t].prerequisites << "test:override_core_fixtures"
  end
end

