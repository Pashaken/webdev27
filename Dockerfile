FROM ruby:4.0.4-slim

WORKDIR /rails

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev libyaml-dev && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p log tmp/cache tmp/pids && \
    chown -R rails:rails log tmp

USER 1000:1000

EXPOSE 3000

CMD ["sh", "-c", "bundle exec rails db:migrate && exec bundle exec puma -C config/puma.rb"]
