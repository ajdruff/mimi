<img src="https://user-images.githubusercontent.com/4875080/34290483-77d72d98-e6ac-11e7-99f0-9efe6502ab81.png" alt="MiMi Logo" width="250" height="250">

# MiMi

MiMi is a mini directory mirror that continuously rsyncs a local directory to your remote server. Multiple instances can run simultaneously on different directories.



## Overview

MiMi is a bash script that runs in the background, reads a configuration file containing information about your local and remote directory and ssh connection details, and continously mirrors the local directory to your remote directory.

To install place a sym link in your system's path (/usr/local/bin will do), and create the configuration file from the sample, placing it in the equivilent etc directory.


## Why MiMi ? 

MiMi is lightweight, doesn't require 3rd party libraries, is flexible, and can handle multiple instances working on multiple directories simultaneously.

Here are some other solutions that you might consider, and the reasons I discounted them.

* lsyncd - doesn't work with VirtualBox shared folders.
* rsync by itself - doesn't run continously and doesn't deal with permissions
* watch - doesn't deal well with VirtualBox shared folders and is not intuitive



## Installation

**download**

    cd ~/src
    git clone git@github.com:ajdruff/mimi.git mimi

**create a symlink in your PATH**

    ln -s ~/src/mimi/mimi.sh ~/bin/mimi

**create the  directory that will hold your configuration files**

    mkdir -p ~/etc/mimi




## Configuration

**create a configuration file from the sample**

    cp ~/src/mimi/sample.conf ~/etc/mimi/devops.conf

**edit the sample values**

    nano ~/etc/mimi/devops.conf




## Example

We want to work on scripts that we'll place in a directory called 'devops' that resides under `/usr/local/sbin` on our remote server.


Create the configuration file and name it `devops`

    cp /usr/local/bin/mimi/sample.conf  /usr/local/etc/mimi/devops.conf

Edit it with the following values:

    source_dir=/home/user/projects/devops
    target_dir=/usr/local/sbin/devops
    ssh_connection_string=cron

    #permissions of directory and all files in directory
    permissions="user::rwx,group::rwx,other::--- -m g:serversup:rwx"

    #owner during sync
    sync_owner="joe:joe"

    #owner after sync is complete. this may be different from sync_owner in the situation you want
    #root to have ownership but root isn't allowed ssh
    final_owner="root:root"

* **source_dir** 
    * This is the absolute path to the local directory that will be mirrored.
* **target_dir** 
    * This is the absolute path to the remote directory that will be the target of the mirror.
* **ssh_connection** This can be as simple as `user@example.com` or ideally should be the Host field value in your local ssh client's configuration file. In the example below, we would just use 'cron' since when we `ssh cron` your client will use that information to create the ssh connection. Here we use `cron` as a special connection that uses a host key with no passphrase (but protected by permissions locally and with an IP restriction in the remote host file) so we can automate remote logins without having to worry about using an ssh-agent or manually adding our passphrase.


            Host cron
            HostName example.com
            User joe
            Port 2222
            PreferredAuthentications publickey
            IdentityFile  /home/user/.ssh/cron/id_rsa




* **permissions** 
    * These are the ACL permissions we'll use to set permissions on our directory and files. 
 
            #permissions of directory and all files in directory
            permissions="user::rwx,group::rwx,other::--- -m g:serversup:rwx"

        Here, we are giving the user and group read,write, and execute permissions of all our files. We also give a separate group `serversup` read,write and execute permissions. No permissions are given to anyone else (others). 

* **sync_owner** 
    * This is the name of the user and group that matches the user that will be logging in. The target directory owner will be changed to `sync_owner` while the daemon is running.
* **final_owner="root:root"**  
    * This is the user and group that will have ownership when the directory isn't being synced. May be different from sync_owner when owner must be root but root isn't allowed to ssh.



## Sudo

If, as in our example, we are having the ssh user change ownership to `root` or do anything that requires root permissions, we'll have to give the user `joe` sudo privileges that don't require a password. Please see `man visudo` documentation on how to do this. 

## Usage

Once the configuration file is saved with name `devops.conf` in `~/etc` directory, we can start our MiMi daemon:

    mimi start devops

Now, every time the daemon runs rsync, the remote directory is updated. 

To stop:

    mimi stop devops

To restart:

    mimi restart devops

To check status:

    mimi status devops

For help:

    mimi --help

For version information:

    mimi --version


## Multiple Instances


Want to sync multiple instances simultaneously? 

create a different configuration file for each job:

* ~/etc/job1.conf
* ~/etc/job2.conf
* ~/etc/job3.conf

and run them all one at a time or all at once:

    mimi start job1
    mimi start job2
    mimi start job3




## Tweaks

### Change the frequency that rsync runs in seconds (the default is 5).

Add the following to your configuration file:

    DAEMON_INTERVAL=5

where 5 is the number of seconds you want the DAEMON to run. 

### Change the location of the configuration directory:

    nano ~/src/mimi/mimi.sh

edit the followig line:

    CONFIG_DIR="~/etc/mimi/"


# Authors

Andrew Druffner andrew@nomstock.com

# License

MIT

# Contributions

Please Fork and send me a pull request, open up an issue or contact me. 
