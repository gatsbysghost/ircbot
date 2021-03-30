# ircbot

# Prerequisites
Your system will need the following:
- docker
- ruby version 2.7+

Quick Install of Ruby:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install rbenv
mkdir -p "$(rbenv root)"/plugins
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
rbenv install 2.7.2
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
```

You will need to restart your shell at this point, then run:

```bash
rbenv global 2.7.2
```

Instructions for installing Docker on your system can be found [here](https://docs.docker.com/get-docker/).

We require some gems for this as well, and in order to install them (a one-time operation), you'll need to run `bundle` in the project directory to use its Gemfile to install required packages:

```bash
bundle
```

# Setup

In order to establish persistent records of requests, this implementation of the chatbot backend uses Redis in a Docker container with persistent storage.

```bash
docker run --name time-irc-redis -p 6379:6379 -d redis redis-server --appendonly yes
```