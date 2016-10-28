# adduser.sh 
Unix add user implementation

View on the [github page](http://sulavvr.github.io/adduser/)

### Usage (command-line interface)
	$ ./adduser -h
	usage: adduser [options] username
	options -
    	--skeleton DIR    specify the skeleton directory (default: /etc/skel)                                                     
    	--home DIR        specify the home directory (default: /home)
	username          name of valid user login on system
	
	$ ./adduser john
	ERROR: cannot add user, must be administrator
	
	$ sudo ./adduser john
	Enter password:                                                                                                                                                                                         
	Re-enter password:                                                                                                                                                                                      
	User john successfully created!   
	
	$ sudo ./adduser --skeleton /etc/skels john
	# creating user john using the /etc/skels to create home directory
	
	$ sudo ./adduser --skeleton /etc/kels john
	ERROR: '/etc/kels' directory not found
	
	$ sudo ./adduser john
	ERROR: 'john' already exists 
	
	$ sudo ./adduser --home /test john
	ERROR: '/test' directory not found 
	
	$ sudo ./adduser --home /var/www john
	# creating user john with /var/www/john as the default home directory	
	
## Steps
- Check if user running the script has root access.
- Check if the given username already exists or not.
- Check the validity of the username `[a-z_][a-z0-9_-]*$`. (Can contain only lowercase alphanumeric with underscore and dash, cannot start with anything other than a lowercase alphabet or an underscore)
- Find the next available user and group ID using the passwd database.
- Ask for password, use python and the crypt library to encrypt password based on `/etc/login.defs` ENCRYPT_METHOD
- Update the `/etc/passwd`, `/etc/group`, `/etc/gshadow` and `/etc/shadow` files. (`/etc/shadow` doesn't need to be updated is using the `passwd` command)
- Copy files from the skeleton directory to the new user's home directory and create a mail spool file.
- Set permissions on the home directory.

## Notes
- Use `/etc/login.defs` to find different configurations for creating mail spool file, UID, GID and encryption method.
- After updating `/etc/passwd` with the record, `passwd username` command can be run to set the password for username for default unix system password setup instead of using the python script to encrypt password manually.
