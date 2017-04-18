# byebug-breakpoints package

This package helps manage the __.byebugrc__ file.

It does the following:
1. Allows you to add and remove byebug breakpoints in the Atom editor. The breakpoints are added into the .byebugrc file which is loaded by byebug when it starts (most of the time)
2. Displays in the editor, breakpoints set in the .byebugrc file when you open the file for editing.
3. Saves updated breakpoints in the .byebugrc file when you save your .rb file - which means the breakpoints move with the code as you remove or insert lines.

## Notes on use

Use:
* <code>cmd-alt-b cmd-alt-b</code> (double tap) to toggle a breakpoint on the current line
* <code>cmd-alt-b s</code> to set a breakpoint on the current line
* <code>cmd-alt-b d</code> to delete a breakpoint on the current line
* <code>cmd-alt-b f</code> to remove all line-based breakpoints for the active editor
* <code>cmd-alt-b a</code> to remove all line-based breakpoints from the .byebugrc file. _If you have breakpoints for multiple projects, they will all be cleared._

Breakpoints are highlighted in the line-number.

### Testing in development
Rails s does not load byebugrc until it encounters a byebug command.
To have breakpoints loaded simply add byebug at the top of any
module - it will run when the module is loaded. 

### Testing inside Atom
I use the __ruby-test__ package for testing in Rails apps in Atom. I found that byebug statements in code caused the package to hang awating byebug commands (because you couldn't interact with it). This was why I wrote this package in the first place.

 I found that ruby-test (really __Cucumber__ and __rspec__) don't load the byebugrc file, so no more hangs.

Here's how rubt-test runs the commands:

 <code>bundle exec rspec --tty {relative_path}:{line_number}</code>

### Testing Outside of Atom (in the terminal)
I found that running rspec using the following command does not appear to load the byebugrc file. rspec will run and byebug commands in code will work, but not breakpoints in the byebugrc file.

<code>$ rspec -p ./spec</code>

This is easily fixed by running it as:

<code>$ byebug --no-stop -- rspec -p -- ./spec</code>

* byebug -- loads byebug and causes the .byebugrc file to be loaded
* --no-stop -- causes byebug to not stop after load, waiting for commands
* -p -- just an example of an rspec option

Note the double-dash before the rspec path.

## Todo:
This is my first Atom package and I haven't created the specs yet.

## Contributions
These helped me get started

* https://github.com/tomkadwill/atom-rails-debugger
* https://github.com/atom/decoration-example
