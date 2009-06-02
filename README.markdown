# Redmine subtasks


This is a plugin for [Redmine](http://www.redmine.org). It was
inspired from Redmine patch issue
[#443](http://www.redmine.org/issues/443).

Plugin's migrations **support** both methods of converting database
from previously patch and migrate from plain, clean Redmine.

## Features

* representation of issues hierarchy in issues's index page; there are
  three options here:

	 + never see issues's hierarchy (sorting and filtering works
     exactly in right behavior),
			
	 + always show parent (sorting and filtering works exactly in right
	 	 behavior, but extra issue can be appearing to show issue's parents
	 	 hierarchy),

	 + organize by parent (sorting and filtering works **after**
	 	 organize issues by its parent);

* autocomplete field for editing issue parent;

* issue's hierarchy on 'show issue' page;

* progress and estimation of parent issue calculated based on its
  children.
	
## Installation

1. Copy the plugin directory into the vendor/plugins directory

2. Migrate plugin:

> 
>    rake db:migrate_plugins
> 

3. Start Redmine

Installed plugins are listed and can be configured from *Admin ->
Plugins* screen.

## Testing

Unfortunately, Redmine core tests which use issues.yml fixture will
fail with this plugin installed.

The good news is that the plugin has each own test for testing its own
functionality. I have added some hack to make the plugin tests
working. The problem that the plugin should use fixtures for issues
with additional fields. Therefore, when you run some of plugin's test
all fixtures from Redmine core copy in separate directory and some
of them are overrides by plugin's fixtures, then unit test runs.
