#!/usr/bin/env ruby

module Support
  extend self

  @@repo_path = "~/vagrant-lamp"
  @@repo_url = "https://github.com/gocodeup/Codeup-Vagrant-Setup/archive/master.zip"
  @@steps = ["start", "xcode", "homebrew", "vagrant_lamp", "git", "sublime", "final"]

  def steps
    @@steps
  end

  def repo_path
    @@repo_path
  end

  def repo_url
    @@repo_url
  end

  def git_download(repo_url, local_path)
    system "curl -L --progress-bar -o /tmp/vagrant_lamp.zip " + repo_url
    system "unzip /tmp/vagrant_lamp.zip -d /tmp"
    system "mv /tmp/Codeup-Vagrant-Setup-master " + repo_path
  end

  def subl_pkg_install(package_path)
    system "curl -L --progress-bar -o \"#{package_path}/Package Control.sublime-package\" https://sublime.wbond.net/Package%20Control.sublime-package"
  end

  def brew_install(package, *options)
    output = `brew list #{package}`
    return unless output.empty?

    system "brew install #{package} #{options.join ' '}"
  end

  def brew_cask_install(package, *options)
    output = `brew cask info #{package}`
    return unless output.include? 'Not installed'

    system "brew cask install #{package} #{options.join ' '}"
  end

  def app_path(name)
    path = "/Applications/#{name}.app"
    ["~#{path}", path].each do |full_path|
      return full_path if File.directory? full_path
    end

    return nil
  end

  def app?(name)
    !self.app_path(name).nil?
  end

  def xcode?
    `xcode-select --print-path 2>&1`

    $?.success?
  end
end

module Steps
  extend self

  def heading(description)
    description = "-- #{description} "
    description = description.ljust(80, '-')
    puts
    puts "\e[32m#{description}\e[0m"
  end

  def block(description)
    line = ''

    description.split(/ /).each do |word|
      if line.length + word.length > 76
        puts "   #{line}"
        line = ''
      end

      line += "#{word} "
    end

    puts "   #{line}"
    puts "\n   Press 'Return' to continue."
    gets
  end

  def do_step(name)
    case name
      when "start"
        self.heading "Welcome!"
      when "xcode"
        self.heading "Setting up Xcode Commandline Tools"
      when "homebrew"
        self.heading "Setting up Homebrew"
      when "vagrant"
        self.heading "Setting up Vagrant Box"
      when "vagrant_lamp"
        self.heading "Checking Out Vagrant LAMP Repository"
      when "git"
        self.heading "Configuring SSH Keys for Git"
      when "final"
        self.heading "Final Configuration Steps"
      when "sublime"
        self.heading "Setting up the Sublime Text editor"
      else
        raise "Unknown step #{name}"
    end

    self.send name
  end

  def start
    description = "This script will go through and make sure you have all the tools you need to get started as a Codeup student. "
    description+= "At several points through this process, you may be asked for a password; this is normal. "
    description+= "Enter the password you use to log in to your computer or otherwise install software normally."

    self.block description
  end

  def xcode
    if Support.xcode?
      self.block "Xcode commandline tool are already installed, moving on."
    else
      description = "We need to install some commandline tools for Xcode. When you press 'Return', a dialog will pop up "
      description+= "with several options. Click the 'Install' button and wait. Once the process completes, come back here "
      description+= "and we will proceed with the next step."

      self.block description

      system "xcode-select --install"

      while !Support.xcode?
        sleep 1
      end
    end
  end

  def homebrew
    `which brew`

    if $?.success?
      description = "Homebrew is already installed. We will check to make sure our other utilities--including Ansible, Vagrant, "
      description+= "and VirutalBox--are also set up."

      self.block description
    else
      description = "We will now install a tool called 'Homebrew'. This is a package manager we will use to install several "
      description+= "other utilities we will be using in the course, including Ansible, Vagrant, and VirtualBox. "
      description+= "You will probably be asked for your password a couple of times through this process; "
      description+= "when you type it in, your password will not be displayed on the screen. This is normal."

      self.block description

      system 'ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"'
    end

    # Install brew cask
    system('brew tap | grep caskroom/cask > /dev/null') || Support.brew_install('caskroom/cask/brew-cask')

    # Install ansible
    Support.brew_install 'ansible'

    # Install Virtual Box
    Support.brew_cask_install "virtualbox" unless Support.app? "VirtualBox"

    # Install Vagrant
    Support.brew_cask_install "vagrant"
  end

  def vagrant_lamp
    full_repo_path = File.expand_path Support.repo_path

    if File.directory?(full_repo_path)
      self.block "Looks like our project directory has already been checked out. On to the next step."
    else
      description = "We will now use Git to download our project directory. This project will set up your Vagrant "
      description+= "environment. All of your development in the class will be done inside this Vagrant environment."

      self.block description

      Support.git_download(Support.repo_url, full_repo_path)
    end

    system "sudo /usr/bin/easy_install passlib"

    puts # add an extra line after the output

    description = "We're going to start up the vagrant box with the command 'vagrant up'. If the box hasn't already been downloaded "
    description+= "this will grab it and configure the internal settings for it. This could take some considerable time so please "
    description+= "be patient. Otherwise, it will simply boot up the box and make sure everything is running."

    self.block description

    system "cd #{full_repo_path} && vagrant up"
  end

  def git
    key_path = File.expand_path "~/.ssh/id_rsa"
    unless File.exists?(key_path) && File.exists?("#{key_path}.pub")
      description = "We're now going to generate an SSH public/private key pair. This key is like a fingerprint for you "
      description+= "on your laptop. We'll use this key for connecting into GitHub without having to enter a password, and "
      description+= "when you ultimately deploy your website to a third party server."

      self.block description

      description = "We will be putting a comment in the SSH key pair as well. Comments can be used to keep track of different "
      description+= "keys on different servers. The comment will be formatted as [your name]@codeup."

      self.block description

      name = ''
      while name.empty?
        print "   Please type in your name and press 'Return'. "
        name = gets.chomp
      end

      system "ssh-keygen -trsa -b2048 -C '#{name}@codeup' -f #{key_path}"
    end

    system "pbcopy < #{key_path}.pub"

    puts "   The following is your new SSH key:\n"
    puts IO.read(key_path + ".pub")
    puts

    description = "We've already copied it to the clipboard for you. Now, we are going to take you to the GitHub website "
    description+= "where you will add it as one of your keys by clicking the \"Add SSH key\" button and pasting "
    description+= "the contents in there."

    self.block description

    system "open https://github.com/settings/ssh"

    self.block "We'll continue once you're done."
  end

  def sublime
    app_path = Support.app_path("Sublime Text") || Support.app_path("Sublime Text 2")

    if app_path.nil?
      self.block "Looks like Sublime Text hasn't been installed yet. You'll need to take care of that before class starts."
      return
    end

    `which subl`

    system "ln -s \"#{app_path}/Contents/SharedSupport/bin/subl\" /usr/local/bin/subl" unless $?.success?

    system "git config --global core.editor \"subl -n -w\""

    description = "We're going to install the Sublime Text Package Manager. This is a plugin for Sublime that makes "
    description+= "it incredibly easy to install other plugins and add functionality to Sublime."

    self.block description

    support_dir = app_path[/Sublime Text 2/] || "Sublime Text 3"

    package_dir = File.expand_path "~/Library/Application Support/#{support_dir}/Installed Packages"

    system "mkdir -p \"#{package_dir}\""

    Support.subl_pkg_install package_dir
  end

  def final
    if IO.readlines("/etc/hosts").grep(/192\.168\.77\.77\s+codeup\.dev/).empty?
      description = "We need to add an entry to your hosts file so we can easily connect to sites in your Vagrant environment. "
      description+= "The hosts file is a shortcut for DNS lookup. We are going to put the domain name 'codeup.dev' in the "
      description+= "hosts file and point it into your Vagrant environment, allowing you to connect into it without "
      description+= "having to memorize IP addresses or ports. This will require you to again put in your password."

      self.block description

      system "sudo sh -c \"echo '\n192.168.77.77\tcodeup.dev' >> /etc/hosts\""

    end

    description = "Now that everything has been configured, we are going to load the codeup.dev site. "
    description+= "This is the site landing page running in YOUR vagrant box inside YOUR OWN computer! "
    description+= "You should see the Codeup logo as well as some information about PHP. Don't worry too "
    description+= "much about what it says for now, we just want to verify that everything is running correctly."

    self.block description

    system "open http://codeup.dev"

    description = "Ok! We've gotten everything setup and you should be ready to go! Thanks for taking the time to "
    description+= "get your laptop configured and good luck in the class."

    self.block description

    puts "     _____         _____           _                  _ "
    puts "    |  __ \\       /  __ \\         | |                | |"
    puts "    | |  \\/ ___   | /  \\/ ___   __| | ___ _   _ _ __ | |"
    puts "    | | __ / _ \\  | |    / _ \\ / _` |/ _ \\ | | | '_ \\| |"
    puts "    | |_\\ \\ (_) | | \\__/\\ (_) | (_| |  __/ |_| | |_) |_|"
    puts "     \\____/\\___/   \\____/\\___/ \\__,_|\\___|\\__,_| .__/(_)"
    puts "                                               | |      "
    puts "                                               |_|      "
  end
end

begin
  Support.steps.each do |step|
    Steps.do_step step
  end
rescue => e
  puts "Oh no! Looks like something has gone wrong in the process."
  puts "Please copy the contents of this window and paste them into an"
  puts "eMail to <instructors@codeup.com>."
  puts "We're sorry about the inconvenience; we'll get the error resolved as quickly"
  puts "as we can and let you know when you may re-run the setup process."
  puts "Error: " + e.message
  puts e.backtrace.join "\n"
end
