# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t why_ruby .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value> --name why_ruby why_ruby

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.1
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

RUN echo 'Acquire::http::Pipeline-Depth 0;\nAcquire::http::No-Cache true;\nAcquire::BrokenProxy true;\n' > /etc/apt/apt.conf.d/99fixbadproxy

# Install base packages and set up jemalloc
RUN rm -rf /var/lib/apt/lists/* && \
    apt-get update -qq --fix-missing && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libssl-dev libvips sqlite3 imagemagick librsvg2-bin && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/lib/libjemalloc.so.2

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/lib/libjemalloc.so.2"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config zlib1g-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock vendor ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Download MaxMind GeoLite2 database for IP geolocation (optional)
RUN --mount=type=secret,id=MAXMIND_ACCOUNT_ID \
    --mount=type=secret,id=MAXMIND_LICENSE_KEY \
    if [ -f /run/secrets/MAXMIND_ACCOUNT_ID ] && [ -f /run/secrets/MAXMIND_LICENSE_KEY ]; then \
      ACCOUNT_ID="$(cat /run/secrets/MAXMIND_ACCOUNT_ID)" && \
      LICENSE_KEY="$(cat /run/secrets/MAXMIND_LICENSE_KEY)" && \
      curl -sL -u "${ACCOUNT_ID}:${LICENSE_KEY}" \
        "https://download.maxmind.com/geoip/databases/GeoLite2-Country/download?suffix=tar.gz" | \
      tar -xzf - --strip-components=1 -C db/ --wildcards "*/*.mmdb" && \
      echo "GeoLite2 database downloaded successfully"; \
    else \
      echo "MAXMIND credentials not provided, skipping GeoLite2 download"; \
    fi

# Precompile bootsnap code for faster boot times (use -j 1 for QEMU compatibility)
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production with RAILS_MASTER_KEY from secrets
RUN --mount=type=secret,id=RAILS_MASTER_KEY \
    RAILS_MASTER_KEY="$(cat /run/secrets/RAILS_MASTER_KEY)" \
    ./bin/rails assets:precompile


# Final stage for app image
FROM base

# OCI labels
LABEL org.opencontainers.image.source="https://github.com/newstler/why_ruby"

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Copy built artifacts: gems, application
COPY --from=build --chown=rails:rails "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --chown=rails:rails /rails /rails

USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
