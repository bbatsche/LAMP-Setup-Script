#!/usr/bin/env ruby

def brew_install(package, *options)
  output = `brew list #{package}`
  return unless output.empty?

  system "brew install #{package} #{options.join ' '}"
end

def brew_cask_install(package, *options)
  output = `brew cask info #{package}`
  return unless output.include?('Not installed')

  system "brew cask install #{package} #{options.join ' '}"
end

def git_clone(user, package, path)
  unless File.exist? File.expand_path(path)
    system "git clone https://github.com/#{user}/#{package} #{path}"
  end
end

def app_path(name)
  path = "/Applications/#{name}.app"
  ["~#{path}", path].each do |full_path|
    return full_path if File.directory?(full_path)
  end

  return nil
end

def app?(name)
  return !app_path(name).nil?
end

def step(description)
  description = "-- #{description} "
  description = description.ljust(80, '-')
  puts
  puts "\e[32m#{description}\e[0m"
end

# Install commandline tools
step "Setting up Xcode Commandline Tools"

`xcode-select --print-path 2>&1`
if $?.success?
  puts "   Xcode Commandline Tools Already Installed"
else
  puts "   Installing Xcode Commandline Tools"

  system "xcode-select --install"
  begin
    sleep 1

    `xcode-select --print-path 2>&1`
  end while !$?.success?
end

# Install homebrew
step "Setting up Homebrew"

`which brew`
if $?.success?
  puts "   Homebrew Already Installed"
else
  puts "   Installing Homebrew Tools"

  system 'ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"'
end

# Install brew cask
system('brew tap | grep phinze/cask > /dev/null') || system('brew tap phinze/homebrew-cask')
brew_install 'brew-cask'

# Install ansible
brew_install 'ansible'

# Install Virtual Box
brew_cask_install "virtualbox" unless app? "VirtualBox"

# Install Vagrant
brew_cask_install "vagrant"

# Download boxfile
# vagrant box add
step "Setting Up Vagrant Box"

# Checkout vagrant-lamp repo
step "Checking Out Vagrant LAMP Repository"

# Edit hosts file
# Generate codeup_rsa key
step "Final Configuration Steps"
