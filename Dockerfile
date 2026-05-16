FROM ruby:3.4.5

# Install system dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libmariadb-dev \
    default-mysql-client \
    netcat-openbsd \
    nodejs \
    npm \
    git \
    curl \
    gnupg \
    apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

# Install Yarn via npm
RUN npm install -g yarn

# Install ClickHouse client
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key' | gpg --dearmor -o /etc/apt/keyrings/clickhouse-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb stable main" > /etc/apt/sources.list.d/clickhouse.list && \
    apt-get update && \
    apt-get install -y clickhouse-client && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies into the dedicated bundle volume path so
# the bind-mounted app source does not hide installed gems at runtime.
RUN bundle config set --global path '/usr/local/bundle' && \
    bundle install

# Copy the rest of the application
COPY . .

# Precompile assets (if needed)
# RUN bundle exec rake assets:precompile

# Create a tmp directory
RUN mkdir -p tmp/pids tmp/cache tmp/sockets

# Expose port 3000
EXPOSE 3000

# Keep the container running
CMD ["bash"]
