# Use Ruby 2.4.9 as base image for Rails 5.0.7.2 compatibility
FROM ruby:2.4.9

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    RAILS_ROOT=/var/www/consul \
    RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# Fix Debian Buster repository issues by using archive repositories
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf.d/99no-check-valid-until

# Install essential Linux packages in a single layer
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      postgresql-client \
      nodejs \
      imagemagick \
      sudo \
      libxss1 \
      libappindicator1 \
      libindicator7 \
      unzip \
      memcached \
      git \
      curl \
      wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install specific Bundler version 2.1.4
RUN gem install bundler -v 2.1.4

# Create consul user with proper permissions
RUN adduser --shell /bin/bash --disabled-password --gecos "" consul && \
    adduser consul sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set secure path for sudo
RUN echo 'Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bundle/bin"' > /etc/sudoers.d/secure_path && \
    chmod 0440 /etc/sudoers.d/secure_path

# Create application directories
RUN mkdir -p $RAILS_ROOT/tmp/pids $RAILS_ROOT/tmp/sockets $RAILS_ROOT/log

# Set working directory
WORKDIR $RAILS_ROOT

# Copy Gemfiles and local gems for dependency caching
COPY Gemfile Gemfile_custom ./
COPY omniauth-ldap ./omniauth-ldap
COPY omniauth-codigo ./omniauth-codigo

# Install gems with bundler 2.1.4 (update to handle Rails version change and mimemagic issue)
RUN bundle install --jobs $BUNDLE_JOBS --retry $BUNDLE_RETRY

# Install Chromium and ChromeDriver for E2E integration tests
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends chromium && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install ChromeDriver compatible with Rails 5.0
RUN wget -N http://chromedriver.storage.googleapis.com/2.38/chromedriver_linux64.zip && \
    unzip chromedriver_linux64.zip && \
    chmod +x chromedriver && \
    mv chromedriver /usr/local/share/chromedriver && \
    ln -s /usr/local/share/chromedriver /usr/local/bin/chromedriver && \
    ln -s /usr/local/share/chromedriver /usr/bin/chromedriver && \
    rm chromedriver_linux64.zip

# Copy entrypoint script
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Copy the Rails application
COPY . .

# Re-run bundle install to ensure git sources are properly checked out
RUN bundle install --jobs $BUNDLE_JOBS --retry $BUNDLE_RETRY

# Set proper ownership
RUN chown -R consul:consul $RAILS_ROOT

# Expose port 3000 for Puma
EXPOSE 3000

# Use entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command for Puma server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
