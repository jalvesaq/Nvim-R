
The easiest way to run R in a remote machine is to log into the remote
machine through ssh, start Neovim, and run R in a Neovim's terminal (the
default). You will only need both Vim (or Neovim) and R configured as usual in
the remote machine.

However, if you need to start either Neovim or Vim on the local machine and
run R in the remote machine, then, a lot of additional configuration is
required to enable full communication between Vim and R because by default
both Nvim-R and nvimcom only accept TCP connections from the local host, and,
R saves temporary files in the `/tmp` directory of the machine where it is
running. To make the communication between local Vim and remote R possible,
the remote R has to know the IP address of local machine, and one remote
directory must be mounted locally. Here is an example of how to achieve this
goal.

  1. Setup the remote machine to accept ssh login from the local machine
     without a password (search the command `ssh-copy-id` over the Internet to
     discover how to do it).

  2. At the remote machine:

     - You have to edit your `~/.Rprofile` to create the environment variable
       `R_IP_ADDRESS`. R will save this value in a file that Vim has to read
       to be able to send messages to R. If the remote machine is a Linux
       system, the following code might work:

       ```r
       # Only create the environment variable R_IP_ADDRESS if NVIM_IP_ADDRESS
       # exists, that is, if R is being controlled remotely:
       if(interactive() && Sys.getenv("NVIM_IP_ADDRESS") != ""){
           Sys.setenv("R_IP_ADDRESS" = trimws(system("hostname -I", intern = TRUE)))
       }
       options(nvimcom.verbose = 4)
       library(colorout)
       ```


  3. At the local machine:

     - Make the directory `~/.remoteR`:

       ```sh
       mkdir ~/.remoteR
       ```

     - Create the shell script `~/bin/mountR` with the following contents, and
       make it executable (of course, replace `remotelogin` and `remotehost`
       with valid values for your case):

       ```sh
       #!/bin/sh
       sshfs remotelogin@remotehost:/home/remotelogin/.cache/Nvim-R ~/.remoteR
       ```

     - Create the shell script `~/bin/sshR` with the following contents, and
       make it executable (replace `remotelogin` and `remotehost` with the
       real values):

       ```sh
       #!/bin/sh

       LOCAL_MOUNT_POINT=$NVIMR_COMPLDIR
       REMOTE_CACHE_DIR=$NVIMR_REMOTE_COMPLDIR
       REMOTE_LOGIN_HOST=remotelogin@remotehost

       NVIM_IP_ADDRESS=$(hostname -I)
       REMOTE_DIR_IS_MOUNTED=$(df | grep $LOCAL_MOUNT_POINT)

       if [ "x$REMOTE_DIR_IS_MOUNTED" = "x" ]
       then
           echo "Remote directory '$REMOTE_CACHE_DIR' not mounted. Quit Vim and start it again." >&2
           sshfs $REMOTE_LOGIN_HOST:$REMOTE_CACHE_DIR $LOCAL_MOUNT_POINT
           sync
           exit 153
       fi

       if [ "x$NVIMR_PORT" = "x" ]
       then
           PSEUDOTERM='-T'
       else
           PSEUDOTERM='-t'
       fi

       ssh $PSEUDOTERM $REMOTE_LOGIN_HOST \
         "NVIMR_TMPDIR=$REMOTE_CACHE_DIR/tmp \
         NVIMR_COMPLDIR=$REMOTE_CACHE_DIR \
         NVIMR_ID=$NVIMR_ID \
         NVIMR_SECRET=$NVIMR_SECRET \
         R_DEFAULT_PACKAGES=$R_DEFAULT_PACKAGES \
         NVIM_IP_ADDRESS=$NVIM_IP_ADDRESS \
         NVIMR_PORT=$NVIMR_PORT R $*"
       ```

     - Add the following lines to your `vimrc` (replace `hostname -I` with a
       command that works in your system):

       ```vim
       let R_app = '/home/locallogin/bin/sshR'
       let R_cmd = '/home/locallogin/bin/sshR'
       let R_compldir = '/home/locallogin/.remoteR
       let R_remote_compldir = '/home/remotelogin/.cache/Nvim-R'
       let R_local_R_library_dir = '/path/to/local/R/library' " where nvimcom is installed
       ```

       if using `init.lua`:

       ```lua
       vim.g.R_app = '/home/locallogin/bin/sshR'
       vim.g.R_cmd = '/home/locallogin/bin/sshR'
       vim.g.R_compldir = '/home/locallogin/.remoteR'
       vim.g.R_remote_compldir = '/home/remotelogin/.cache/Nvim-R'
       vim.g.R_local_R_library_dir = '/path/to/local/R/library' -- where nvimcom is installed
       ```

     - Manually build nvimcom, copy the source to the remote machine, access
       the remote machine and install the package:

       ```sh
       cd /tmp
       R CMD build /path/to/Nvim-R/R/nvimcom
       scp nvimcom_0.9-149.tar.gz remotelogin@remotehost:/tmp
       ssh remotelogin@remotehost
       cd /tmp
       R CMD INSTALL nvimcom_0.9-149.tar.gz
       ```

     - Mount the remote directory:

       ```sh
       ~/bin/mountR
       ```

     - Start Neovim (or Vim), and start R.
