On an appropriate macOS computer, create a new user account with admin privileges, and log in to that account.

Open the script at https://github.com/tomackroyd/archive-dvd/blob/main/ARCHIVE%20DVD-VIDEO.zsh
You will need Tom to log in to this Github account.

Copy and paste the contents into a text file and save locally as ARCHIVE-DVD-VIDEO-STAFF.zsh
Make a note of where this is saved.

Install Homebrew by running:
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

Then:
`brew install ffmpeg`

`brew install MakeMKV`

`brew install jq`

`brew install exiftool`

`brew install mediainfo`

`brew install IINA`

`brew install amiaopensource/amiaos`


Also install Invisor from the App store
run `brew cleanup` and `brew doctor`

Add `/opt/homebrew/bin` to the new User’s PATH by running `"export PATH="/opt/homebrew/bin:$PATH"`

Run `which ffmpeg` and  `which jq` to check path is `/usr/local/bin`

Test the script for access to all applications, especially jq
Copy the path of the .zsh script and run `chmod +x <path>`
Disk Imaging can now be run on the admin account.

If setting up a Preservation Workstation, log out of the admin account, and change its privileges to Staff

Log in to the staff account

In Terminal, add `/opt/homebrew/bin` to the staff User’s PATH by running
`export PATH="/opt/homebrew/bin:$PATH"`
and similarly for makemkvcon:
`export PATH="/Applications/MakeMKV.app/Contents/MacOS:$PATH"`

Log back in and test
