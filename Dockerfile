# syntax = docker/dockerfile:experimental
FROM kingdonb/rvm-supported:latest as builder-base
LABEL maintainer="Kingdon Barrett <kingdon.b@nd.edu>"
ENV APPDIR="/home/${RVM_USER}/app"
ENV RUBY=2.5.8

USER root
COPY jenkins/runasroot-dependencies.sh /home/${RVM_USER}/jenkins/
RUN /home/${RVM_USER}/jenkins/runasroot-dependencies.sh
RUN chgrp rvm /usr/local/bin && chmod g+w /usr/local/bin

FROM builder-base AS gem-builder-base
USER ${RVM_USER}
COPY --chown=rvm Gemfile Gemfile.lock .ruby-version ${APPDIR}/

FROM builder-base AS jenkins-builder
COPY jenkins/runasroot-jenkins-dependencies.sh /home/${RVM_USER}/jenkins/
RUN /home/${RVM_USER}/jenkins/runasroot-jenkins-dependencies.sh

FROM gem-builder-base AS gem-bundle
RUN mkdir -p -m 0700 ~/.ssh && ssh-keyscan bitbucket.org 18.205.93.2 18.205.93.0 >> ~/.ssh/known_hosts
ENV LD_LIBRARY_PATH /opt/oracle/instantclient_19_8
RUN --mount=type=ssh,uid=999,gid=1000 \
    rvm ${RUBY}         do rvm gemset create testing \
 && rvm ${RUBY}@testing do bundle check \
 || rvm ${RUBY}@testing do bundle install
RUN echo 'export PATH="$PATH:$HOME/app/bin"' >> ~/.profile \
 && echo "rvm ${RUBY}@testing" >> ~/.profile

# FROM gem-bundle AS assets
# COPY --chown=${RVM_USER} Rakefile ${APPDIR}
# COPY --chown=${RVM_USER} config ${APPDIR}/config
# COPY --chown=${RVM_USER} bin ${APPDIR}/bin
# COPY --chown=${RVM_USER} app/assets ${APPDIR}/app/assets
# COPY --chown=${RVM_USER} lib/nd_workflow_class_methods.rb ${APPDIR}/lib/nd_workflow_class_methods.rb
# COPY --chown=${RVM_USER} vendor/assets ${APPDIR}/vendor/assets
# # COPY --chown=${RVM_USER} app/javascript ${APPDIR}/app/javascript/
# RUN --mount=type=cache,uid=999,gid=1000,target=/home/rvm/app/public/assets \
#   rvm ${RUBY}@testing do bundle exec rails assets:precompile && cp -ar /home/rvm/app/public/assets /tmp/assets

FROM gem-bundle AS builder
COPY --from=assets --chown=${RVM_USER} /tmp/assets ${APPDIR}/public/assets
FROM builder AS slug
COPY --chown=${RVM_USER} . ${APPDIR}
USER ${RVM_USER}
# RUN echo 'export PATH="$PATH:$HOME/app/bin"' >> ../.profile

FROM jenkins-builder AS jenkins
COPY --from=gem-bundle --chown=${RVM_USER} /usr/local/rvm/gems/ruby-${RUBY}@testing /usr/local/rvm/gems/ruby-${RUBY}@testing
COPY --from=slug --chown=${RVM_USER} ${APPDIR} ${APPDIR}
USER root
RUN useradd -m -u 1000 -g rvm jenkins
USER jenkins
ENV LD_LIBRARY_PATH /opt/oracle/instantclient_19_8

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
CMD  bash --login -c 'rvm ${RUBY}@testing do bundle exec rails server -b 0.0.0.0'
EXPOSE 3000
