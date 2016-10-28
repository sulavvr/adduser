#!/bin/bash

# set default values for variables
default_skel_directory="/etc/skel"
default_home_directory="/home"
passwd_file="/etc/passwd"
login_def="/etc/login.defs"
password=""
confirm="_"
encryption=""
min_uid=""
min_gid=""
default_bash="/bin/bash"
# check if user running the script is root
function checkIfRoot() {
    if [ "$USER" != "root" ]; then
      echo "ERROR: cannot add user, must be administrator" >&2
      exit
    fi
}
# get default mail directory from /etc/login.defs
function getMailDir() {
    default_mail_dir=$(grep -i 'MAIL_DIR' $login_def | tail -2 | head -1 | tr -s [:space:] | cut -d" " -f2)
}
# search user in the passwd database, if exists, exit with error
function searchUser() {
    passed_user=$1
    # get users list from /etc/passwd
    users_list=$(getent passwd | cut -d: -f1)
    for u in $users_list; do
      if [ $u == $passed_user ]; then
        echo "ERROR: '$passed_user' already exists" >&2
        exit
      fi
    done
}
# get next available user and group id to assign to the user being added
# uid min and gid min values defined in /etc/login.defs
function getUidAndGid() {
    min_uid=$(grep -i 'UID_MIN' $login_def | head -1 | tr -s [:blank:] | cut -d" " -f2)
    min_gid=$(grep -i 'GID_MIN' $login_def | head -1 |  tr -s [:blank:] | cut -d" " -f2)
    
    # get uids greater than 1000 as defined in /etc/login.defs
    uids=$(getent passwd | awk -F: '$3 > '$min_uid' {print $3}')
    gids=$(getent passwd | awk -F: '$4 > '$min_gid' {print $4}')
    
    # add 1, so the next uid and gid is not the system assigned ids
    new_uid=$[min_uid+1]
    new_gid=$[min_gid+1]
    
    # loop unti next uid and gid are found
    while [[ true ]]; do
        u_find=$(echo $uids | grep -cE '\b'$new_uid'\b')
        g_find=$(echo $gids | grep -cE '\b'$new_gid'\b')
        
        if [[ $u_find == 0 ]] && [[ $g_find == 0 ]]; then
            break
        fi
        
        # check if the new_uid exists in the $uids variable
        if [[ $u_find > 0 ]]; then
            new_uid=$[new_uid+1]
            continue        
        fi
        
        # check if the new_uid exists in the $uids variable
        if [[ $g_find > 0 ]]; then
            new_gid=$[new_gid+1]
            continue        
        fi
    done
    
    echo $new_uid $new_gid
}
# get the type of encryption defined in /etc/login.defs
function getEncryption() {
    encryption=$(grep -i 'ENCRYPT_METHOD' $login_def | head -2 | tail -1 | tr -s [:blank:] | cut -d" " -f2)
}
# check if passwords match and encrypt it, encryption method defined in /etc/login.defs
function checkPass() {
     while [[ $password != $confirm ]]; do
        echo -n "Enter password: "         
        read -s password
        printf "\n"
        echo -n "Re-enter password: "        
        read -s confirm
        printf "\n"
        
        if [[ $password != $confirm ]]; then
            printf "Whoops! Passwords don't match!\n"
        fi
    done
    
    # get the encryption method from /etc/login.defs, exit if method is DES or undefined
    getEncryption
    
    
    # available encryption methods in python's crypt library:
    # - crypt.METHOD_MD5
    # - crypt.METHOD_SHA256
    # - crypt.METHOD_SHA512 // usually defined in /etc/login.defs
    if [ $encryption ] && [ $encryption != "DES" ]; then
        # using python to generate a sha512 encrypted password
        encrypt_passwd=$(python3 -c 'import crypt; print(crypt.crypt("'$password'", crypt.mksalt(crypt.METHOD_'$encryption')))')
    else
        echo "Encryption undefined... check /etc/login.defs to define ENCRYPT_METHOD (MD5, SHA256 or SHA512 allowed)" >&2
        exit
    fi
}
# create the home directory and the mail spool for user
function setupDirectories() {
    
    # home directory can be defined when createing a user otherwise default is used
    if [ $1 ]; then
        home_dir=$1/$user
    else
        home_dir=$default_home_directory/$user
    fi
    
    # create directory
    #mkdir $home_dir
    
    # get mail directory
    getMailDir
    
    # create mail directory
    mail_file=$default_mail_dir/$user
    
    # create the mail spool file
    touch $mail_file
}
# get all the required configurations defined in /etc/login.defs
# PASS_MAX_DAYS, PASS_MIN_DAYS, PASS_WARN_AGE
function getConfig() {
    pass_max_days=$(grep -i 'PASS_MAX_DAYS' $login_def | tail -1 | tr [:blank:] " " | cut -d" " -f2)
    pass_min_days=$(grep -i 'PASS_MIN_DAYS' $login_def | tail -1 | tr [:blank:] " " | cut -d" " -f2)
    pass_warn_age=$(grep -i 'PASS_WARN_AGE' $login_def | tail -1 | tr [:blank:] " " | cut -d" " -f2)
}
# build records to be added to the /etc/passwd, /etc/group, /etc/shadow and /etc/gshadow files
function buildRecords() {
    # get configuration parameters from /etc/login.defs
    getConfig
    
    # build records for addition
    passwd=$user:x:$new_uid:$new_gid::$home_dir:$default_bash
    group=$user:x:$new_gid
    shadow=$user:$encrypt_passwd:$(date +%s):$pass_min_days:$pass_max_days:$pass_warn_age:::
    gshadow=$user:!::
    
    # Write records to the appropriate files
    echo $passwd >> /etc/passwd
    echo $group >> /etc/group
    echo $shadow >> /etc/shadow
    echo $gshadow >> /etc/gshadow
    
    # change owner on the created mail directory
    chown $user:$user $mail_file
    
    #cabox:!::
    #cabox:$6$yeA5NSIz$rWUyRMLAK4NFIEoy/LmX76FTOZ.o1hH7SHRfbufVP8/HNw/YMA0tzO9A0ByuqKHItudgY0hj.3DgD5zwMFIig1:16325:0:99999:7::: 
    #cabox:x:1000: 
    #cabox:x:1000:1000::/home/cabox:/bin/bash
}
# copy skeleton files to the home directory, 
# default /etc/skel contains .bashrc, .profile etc..
function copySkelToHome() {
    # skeleton directory can be defined when createing a user otherwise default is used
    if [ $1 ]; then
        skel_dir=$1
    else
        skel_dir=$default_skel_directory
    fi
    
    # copy all files from the skeleton directory to the home directory recursively
    cp -r $skel_dir $home_dir
    
    # change owner and permissions on the created home directory
    chown -R $user:$user $home_dir
    chmod -R 755 $home_dir
}
# check to see if the username is valid.
# can only contain lowercase letters and numbers and star with lowercase a to z or underscore
function checkUsername() {
    # using grep to check the number of matches and return count
    check=$(echo $user | grep -cE "^[a-z_][a-z0-9_-]*$")
    if [[ $check == 0 ]]; then
        echo "Invalid characters used. Username can only start with lowercase letter or an underscore and can only contain" >&2
        echo " alphanumeric values or an underscore(_) or a dash(-)"
        exit
    fi
}
# read arguments
case "$1" in
    # sudo adduser --skeleton $dir $username
    --skeleton)
        # check if user is root
        checkIfRoot
        
        while [ $1 ]; do
            shift
            skel_dir_provided=$1
            
            if [[ ! -d $skel_dir_provided ]]; then
                echo "ERROR: '$skel_dir_provided' directory not found" >&2
                exit
            fi
            shift
            user=$1
            if [ ! $user ]; then
                echo "ERROR: username not given" >&2
                exit
            fi
            
            # check username validity
            checkUsername
            # call searchUser function
            searchUser $user
            
            # get uid & gid
            getUidAndGid
        
            # check password & encrypt it
            checkPass
            
            # create home directory
            setupDirectories $home_dir_provided
            
            # build shadow, passwd, gpasswd and group records
            buildRecords
            
            # copy skel files to home directory
            copySkelToHome $skel_dir_provided     
            
            echo "User $user successfully created!"
            
            shift
        done 
    ;;
    # sudo adduser --home $dir $username
    --home)
        # check if user is root
        checkIfRoot
        
        while [ $1 ]; do
            # move to next argument
            shift
            home_dir_provided=$1
            
            if [[ ! -d $home_dir_provided ]]; then
                echo "ERROR: '$home_dir_provided' directory not found" >&2
                exit
            fi
            # move to next argument
            shift
            
            user=$1
            if [ ! $user ]; then
                echo "ERROR: username not given" >&2
                exit
            fi
            
            # check username validity
            checkUsername
            # call searchUser function
            searchUser $user
            
            # get uid & gid
            getUidAndGid
        
            # check password & encrypt it
            checkPass
            
            # create home directory
            setupDirectories $home_dir_provided
            
            # build shadow, passwd, gpasswd and group records
            buildRecords
            
            # copy skel files to home directory
            copySkelToHome  
            
            echo "User $user successfully created!"
            
            shift
        done 
    ;;
    
    -h)
        printf "usage: adduser [options] username\n" >&2
        printf "options - \n" >&2
        printf "    --skeleton DIR    specify the skeleton directory (default: /etc/skel)\n" >&2
        printf "    --home DIR        specify the home directory (default: /home)\n\n" >&2
        printf "username          name of valid user login on system\n" >&2
    ;;
    # sudo adduser $username
    # catch-all case
    *)
        # check if user is root
        checkIfRoot
        
        user=$1
        if [ ! $user ]; then
            echo "ERROR: username not given" >&2
            exit
        fi
        
        # check username validity
        checkUsername
    
        # call searchUser function
        searchUser $user
        # get uid & gid
        getUidAndGid
        
        # check password & encrypt it
        checkPass
        # create home directory
        setupDirectories
        # build shadow, passwd, gpasswd and group records
        buildRecords
        
        # copy skel files to home directory
        copySkelToHome 
        
        echo "User $user successfully created!"
    ;;
    
esac
