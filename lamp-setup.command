#!/usr/bin/env ruby

module Support
  extend self

  @@repo_path = "~/vagrant-lamp"
  @@repo_url = "https://github.com/gocodeup/vagrant-lamp/archive/master.zip"
  @@steps = ["start", "xcode", "homebrew", "git", "final"]

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
    system "mv /tmp/vagrant-lamp-master " + repo_path
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
  end

  def app?(name)
    !self.app_path(name).nil?
  end

  def xcode?
    `xcode-select --print-path 2>&1`

    $?.success?
  end

  def repo_checked_out?(path)
    `cd #{path} && git status`

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

    description.split.each do |word|
      if line.length + word.length > 76
        puts "   #{line}"
        line = ''
      end

      line += "#{word} "
    end

    puts "   #{line}"
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
        self.heading "Setting Up Vagrant Box"
      when "git"
        self.heading "Checking Out Vagrant LAMP Repository"
      when "final"
        self.heading "Final Configuration Steps"
      else
        raise "Unknown step #{name}"
    end

    self.send name
  end

  def start
    description = "This script will go through and make sure you have all the tools you need to get started as a Codeup student. "
    description+= "At several points through this process, you may be asked for a password; this is normal. "
    description+= "Enter the password you use to log in to your computer or otherwise install software normally. "
    description+= "To get started press the 'Return' key on your keyboard."

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

      system 'ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"'
    end

    # Install brew cask
    system('brew tap | grep phinze/cask > /dev/null') || system('brew tap phinze/cask')
    Support.brew_install 'brew-cask'

    # Install ansible
    Support.brew_install 'ansible'

    # Install Virtual Box
    Support.brew_cask_install "virtualbox" unless Support.app? "VirtualBox"

    # Install Vagrant
    Support.brew_cask_install "vagrant"
  end

  def vagrant
    boxes = `vagrant box list`

    if boxes.include? "codeup-raring"
      description = "Looks like you've already setup our vagrant box, we'll move on."

      self.block description
    else
      description = "Now we will download our vagrant box file. Vagrant is a utility for managing virtual machines, and "
      description+= "a box file contains a virtual machine definition and its code. Be patient! This file is a little over "
      description+= "400MB and will take a while to download."

      self.block description

      system "vagrant box add codeup-raring #{Support.box_url}"
    end
  end

  def git
    full_repo_path = File.expand_path Support.repo_path

    if File.directory?(full_repo_path) && Support.repo_checked_out?(full_repo_path)
      self.block "Looks like our project directory has already been checked out. On to the next step."
    else
      description = "We will now use Git to download our project directory. This project will set up your Vagrant "
      description+= "environment. All of your development in the class will be done inside this Vagrant environment."

      self.block description

      Support.git_download(Support.repo_url, full_repo_path)

      # set up vagrant box in the repo
    end
  end

  def final
    if IO.readlines("/etc/hosts").grep(/192\.168\.77\.77\s+codeup\.dev/).empty?
      description = "We need to add an entry to your hosts file so we can easily connect to sites in your Vagrant environment. "
      description+= "The hosts file is a shortcut for DNS lookup. We are going to put the domain name 'codeup.dev' in the "
      description+= "hosts file and point it into your Vagrant environment, allowing you to connect into it without "
      description+= "having to memorize IP addresses or ports. This will require you to again put in your password."

      self.block description

      system "sudo sh -c \"echo '\n192.168.77.77\tcodeup.dev' >> /etc/hosts\""

      # open codeup.dev in web browser
    end

    key_path = File.expand_path "~/.ssh/codeup_rsa"
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

      system "ssh-keygen -trsa -b2048 -C '#{name}@codeup' -f ~/.ssh/codeup_rsa"

      # give instructions on adding key to GitHub.com?
    end

    ssh_config = File.expand_path "~/.ssh/config"
    unless File.exists?(ssh_config) && !IO.readlines(ssh_config).grep(/^\s*Host(?:Name)?\s+github\.com/).empty?
      File.open(ssh_config, "a") do |config|
        config.puts "Host github.com"
        config.puts "\tUser git"
        config.puts "\tIdentityFile ~/.ssh/codeup_rsa"
      end
    end

    description = "Ok! We've gotten everything setup and you should be ready to go! Thanks for taking the time to "
    description+= "get your laptop configured and good luck in the class. Go Codeup!"

    self.block description
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
