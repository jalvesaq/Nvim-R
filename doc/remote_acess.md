
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
each application has to know the IP address of the other, and some remote
directories must be mounted locally. Here is an example of how to achieve this
goal. This used to work in the past (tested on April 2017) but no longer
works.

If anyone ever want to try to fix the code to allow the remote access again,
the starting point is:

  1. Setup the remote machine to accept ssh login from the local machine
      without a password (search the Internet to discover how to do it).

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

       If the code above does not work, you have to find a way of discovering
       the IP address of the remote machine (perhaps parsing the output of
       `ifconfig`).

  3. At the local machine:

     - Make the directories `~/.remoteR/NvimR_cache` and `~/.remoteR/R_library`.

     - Create the shell script `~/bin/mountR` with the following contents, and
       make it executable (of course, replace `remotelogin`, `remotehost` and
       the path to R library with valid values for your case):

       ```sh
       #!/bin/sh
       sshfs remotelogin@remotehost:/home/remotelogin/.cache/Nvim-R ~/.remoteR/NvimR_cache
       sshfs remotelogin@remotehost:/home/remotelogin/R/x86_64-pc-linux-gnu-library/4.2 ~/.remoteR/R_library
       ```

     - Create the shell script `~/bin/sshR` with the following contents, and
       make it executable (replace `remotelogin` and `remotehost` with the
       real values):

       ```sh
       #!/bin/sh
       ssh -t remotelogin@remotehost "PATH=/home/remotelogin/bin:\$PATH \
       NVIMR_COMPLDIR=~/.cache/Nvim-R \
       NVIMR_TMPDIR=~/.cache/Nvim-R/tmp \
       NVIMR_ID=$NVIMR_ID \
       NVIMR_SECRET=$NVIMR_SECRET \
       R_DEFAULT_PACKAGES=$R_DEFAULT_PACKAGES \
       NVIM_IP_ADDRESS=$NVIM_IP_ADDRESS \
       NVIMR_PORT=$NVIMR_PORT R $@"
       ```

     - Add the following lines to your `vimrc` (replace `hostname -I` with a
       command that works in your system):

       ```vim
       " Setup Vim to use the remote R only if the output of df includes
       " the string 'remoteR', that is, the remote file system is mounted:
       if system('df') =~ 'remoteR'
           let $NVIM_IP_ADDRESS = substitute(system("hostname -I"), " .*", "", "")
           let R_app = '/home/locallogin/bin/sshR'
           let R_cmd = '/home/locallogin/bin/sshR'
           let R_compldir = '/home/locallogin/.remoteR/NvimR_cache'
           let R_tmpdir = '/home/locallogin/.remoteR/NvimR_cache/tmp'
           let R_remote_tmpdir = '/home/remotelogin/.cache/NvimR_cache/tmp'
           let R_local_R_library_dir = '/home/locallogin/path/to/R/library'
           let R_nvimcom_home = '/home/locallogin/.remoteR/library/nvimcom'
        endif
        ```

        if using `init.lua`:

        ```lua
        -- Setup Neovim to use the remote R only if the output of df includes
        -- the string 'remoteR', that is, the remote file system is mounted:
        local a
        a = io.popen('/usr/bin/df', "r")
        if a then
            local output = a:read("*a")
            a:close()
            if string.find(output, 'remoteR') then
                a = io.popen("hostname -I", "r")
                if a then
                    local h
                    h = string.gsub(a:read("*a"), "\n", "")
                    a:close()
                    vim.fn.setenv('NVIM_IP_ADDRESS', h)
                    vim.g.R_app = '/home/locallogin/bin/sshR'
                    vim.g.R_cmd = '/home/locallogin/bin/sshR'
                    vim.g.R_compldir = '/home/locallogin/.remoteR/NvimR_cache'
                    vim.g.R_tmpdir = '/home/locallogin/.remoteR/NvimR_cache/tmp'
                    vim.g.R_remote_tmpdir = '/home/remotelogin/.cache/Nvim-R/tmp'
                    vim.g.R_local_R_library_dir = '/home/locallogin/path/to/R/library'
                    vim.g.R_nvimcom_home = '/home/locallogin/.remoteR/library'
                end
            end
        end
        ```

     - Mount the remote directories:

       ```sh
       ~/bin/mountR
       ```

     - Start Neovim (or Vim), and start R.
