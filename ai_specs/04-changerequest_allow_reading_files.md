# allow reading files from ShelfScreen
- currently on macos: when a previously loaded file is clicked on Shelfscreen, a message is displayed:
"Operation not permitted"
- if a file was opened with a filepicker, the read is allowed
- add a gear icon to the app bar
  - when clicked -> display a SettingsScreen with these properties
    - a button: Allow access to directory
    - a list of currently allowed directories
- ask the user to allow access to his home-diectory 
  - use package macos_secure_bookmarks to allow access to all files in this directory