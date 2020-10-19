# syntax = docker/dockerfile:experimental
FROM kingdonb/docker-rvm-support:latest-oci8 as builder-base
LABEL maintainer="Kingdon Barrett <kingdon.b@nd.edu>"
ENV APPDIR="/home/${RVM_USER}/app"
ENV RUBY=2.5.8

USER root
COPY jenkins/runasroot-dependencies.sh /home/${RVM_USER}/jenkins/
RUN /home/${RVM_USER}/jenkins/runasroot-dependencies.sh

USER ${RVM_USER}
RUN bundle config set app_config .bundle && \
  bundle config set path /tmp/.cache/bundle && mkdir -p /tmp/.cache/bundle
COPY --chown=rvm Gemfile Gemfile.lock .ruby-version ${APPDIR}/
RUN echo 'gem: --no-document' > ~/.gemrc && \
  rvm ${RUBY}@global do gem update bundler && \
  rvm ${RUBY}@global do gem update --system

FROM builder-base AS bundler
RUN mkdir -p -m 0700 ~/.ssh && ssh-keyscan bitbucket.org 18.205.93.2 18.205.93.0 >> ~/.ssh/known_hosts
ENV LD_LIBRARY_PATH /opt/oracle/instantclient_19_8
COPY --chown=${RVM_USER} jenkins/rvm-bundle-cache-build.sh /home/${RVM_USER}/jenkins/
RUN --mount=type=cache,uid=999,gid=1000,target=/tmp/.cache/bundle \
    --mount=type=ssh,uid=999,gid=1000 \
    /home/${RVM_USER}/jenkins/rvm-bundle-cache-build.sh ${RUBY}
RUN echo 'export PATH="$PATH:$HOME/app/bin"' >> ../.profile

# FROM bundler AS assets
# COPY --chown=${RVM_USER} Rakefile ${APPDIR}
# COPY --chown=${RVM_USER} config ${APPDIR}/config
# COPY --chown=${RVM_USER} bin ${APPDIR}/bin
# COPY --chown=${RVM_USER} app/assets ${APPDIR}/app/assets
# COPY --chown=${RVM_USER} lib/nd_workflow_class_methods.rb ${APPDIR}/lib/nd_workflow_class_methods.rb
# COPY --chown=${RVM_USER} vendor/assets ${APPDIR}/vendor/assets
# # COPY --chown=${RVM_USER} app/javascript ${APPDIR}/app/javascript/
# RUN --mount=type=cache,uid=999,gid=1000,target=/home/rvm/app/public/assets \
#   rvm ${RUBY} do bundle exec rails assets:precompile && cp -ar /home/rvm/app/public/assets /tmp/assets

FROM builder-base AS builder
COPY --from=bundler --chown=${RVM_USER} /tmp/vendor/bundle ${APPDIR}/vendor/bundle
# COPY --from=assets --chown=${RVM_USER} /tmp/assets ${APPDIR}/public/assets
FROM builder AS slug
COPY --chown=${RVM_USER} . ${APPDIR}
RUN bundle config set app_config .bundle && \
    bundle config set path vendor/bundle
# RUN echo 'export PATH="$PATH:$HOME/app/bin"' >> ../.profile

FROM slug AS jenkins
USER root
RUN useradd -m -u 1000 -g rvm jenkins
USER jenkins
RUN bundle config set app_config .bundle && \
    bundle config set path vendor/bundle

# RUN echo 'export PATH="$PATH:/home/rvm/app/bin"' >> ~/.profile

FROM slug AS prod
USER ${RVM_USER}
# USER root
# ENTRYPOINT ["/sbin/my_init", "--"]

# # Example downstream Dockerfile:
FROM slug as test
RUN bundle config set app_config .bundle
ENV LD_LIBRARY_PATH /opt/oracle/instantclient_19_8
# If your app uses a different startup routine or entrypoint, set it up here
CMD  bash --login -c 'bundle exec rails server -b 0.0.0.0'
EXPOSE 3000
