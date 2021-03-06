## Jenkinsfile for Rails 5

To bootstrap your Rails application with a Jenkins CI pipeline, copy everything
from this repo and add it to your app repo. If you are upgrading to Rails 5,
the notes that follow may provide valuable assistance to support your efforts!

#### `Jenkinsfile`

There is some front-matter in the Jenkinsfile which must be customized for your
application's container registry or image repository, but otherwise the files
in this repo are meant to be copied into your project unmodified to support a
Jenkins pipeline that builds and tests your application on Jenkins/Kubernetes.

```Jenkinsfile
dockerRepoHost = 'registry.kingdonb.dev'
dockerRepoUser = 'admin'
dockerRepoProj = 'hrpy-api'

jenkinsDockerSecret = 'docker-registry-admin'
jenkinsSshSecret    = 'jenkins-ssh'

gitCommit = ''
imageTag = ''
```

- `dockerRepoHost`: image registry ("image repository") address
- `dockerRepoUser`: a "registry user" - eg. push to `registry.kingdonb.dev/admin/hrpy-api`
- `dockerRepoProj`: project name, or app image name

The `dockerRepo*` values above should be varied on a per-project basis.

- `jenkinsDockerSecret`:

If your registry requires a push secret, have a Jenkins admin load it into the
Jenkins server's credentials store and refer to it here by its "credential id".

- `jenkinsSshSecret`:

If your build requires access to internal git dependencies or any repository
protected by SSH encryption keys, have a Jenkins admin load the SSH key here.
(Jenkins' BlueOcean front end interface has generated `jenkins-ssh` for us.)

These jenkins*Secret values usually do not vary from one project to the next.

- `gitCommit = ''`
- `imageTag = ''`

These variables should remain unset. They will be populated by the pipeline
scripts below, making use of the Jenkinsfile's implicit SCM checkout step.

If you are building from a tag ref, `imageTag` will detect the tag and your
generated image will bear that tag when it is pushed to the ECR image repo.

If your build is from a branch ref, `gitCommit` is populated with the 8-char
short git SHA; Jenkins will attempt to push that tag on success, instead.

In that case, through `imageTag` a value like `a1b2c3d9-example` is written,
for a commit with that short hash on a branch named `example`. It is shown
pushed to the ECR image repository.

A simpler example that does not take different push actions based on a failed
or successful test run and always pushes both gitCommit and imageTag is in
`examples/Jenkins.minimal`. If your registry or dependencies are private, you
will most likely need to use the full Jenkinsfile instead.

Project teams are welcome to tailor or modify these steps inside your repo!

#### Repository Structure

From this repository, you should copy:

`jenkins/` - Copy this directory of scripts into your repo, and modify
`rake-ci.sh` to suit your needs. This is the main test executor script.
The rest of these files should be kept unmodified.

`Jenkinsfile` or `examples/Jenkinsfile.minimal` - Read the information above to
understand which of these example files to copy to `Jenkinsfile` in the
repository project root directory. Your project should only keep one.

`lib/tasks/ci.rake` - This is a basic smoke test for CI. If your project does
not yet have any test suite, this can be used to guarantee that each successful
image build that passes the Test stage has completed `bundle install`, and can
also at least run `bundle check` and load Rails into the Ruby VM without error.
If you prefer to run your own test suite, edit `jenkins/rake-ci.sh` and adding
this file to your repository can be skipped.

Invoke the `ci:test` rake task manually by running: `rake ci`.

`.dockerignore`, `.gitignore`, `.stignore` - When developers handle tokens and
secrets, care must be taken to prevent them from being copied into git. Now
with containers, there is a new risk that secrets are accidentally copied in a
`docker build` image. Copy these and take care when handling secrets that you
add any secret files to these listings, so that you can mitigate this. (Devs
can also mitigate this risk by always letting the pipeline build the images.)

`Makefile` - running `make` in this Jenkinsfile-example directory creates a
tarball, `../Jenkinsfile-example.tar.gz`, that contains the latest version of
each of these files, so you can copy them all into your project at once.

`Makefile.txt` - to run `docker build` as Jenkins does it, some params must
be set. This makefile sets up those parameters just as the Build stage does.
It then calls `jenkins/docker-build.sh` just as the Build stage does, this is
useful when testing a change in the Dockerfile, to re-run and verify it locally
before pushing again to git; then you can avoid repeated pipeline failures.
You can save this file as `Makefile`, or run `make -f Makefile.txt` to use it.

And `Dockerfile`, of course, which can be customized if needed for your app.
If you are running an API with no asset pipeline, you can delete some lines.
Otherwise, if your application has a front-end and uses asset pipeline, you can
uncomment the commented lines.

```Dockerfile
FROM gem-bundle AS assets
COPY --chown=${RVM_USER} Rakefile ${APPDIR}
COPY --chown=${RVM_USER} config ${APPDIR}/config
COPY --chown=${RVM_USER} bin ${APPDIR}/bin
COPY --chown=${RVM_USER} app/assets ${APPDIR}/app/assets
# COPY --chown=${RVM_USER} lib/nd_workflow_class_methods.rb ${APPDIR}/lib/nd_workflow_class_methods.rb
# COPY --chown=${RVM_USER} vendor/assets ${APPDIR}/vendor/assets
# COPY --chown=${RVM_USER} app/javascript ${APPDIR}/app/javascript/
RUN --mount=type=cache,uid=999,gid=1000,target=/home/rvm/app/public/assets \
  rvm ${RUBY}@${GEMSET} do bundle exec rails assets:precompile && cp -ar /home/rvm/app/public/assets /tmp/assets
```

At this stage of the build, the `Dockerfile` has copied only the needed files
so that `asset:precompile` does not repeat again unnecessarily when unrelated
files change, so that it can be re-run only when needed. Some applications will
require additional files like the still- commented lines shown here.

You may tailor this section, or any others, to your app's needs as required.
Generally, the intention of this guidance is that `Dockerfile` should not need
to change very much, (even at all,) other than as described here. (Instead, one
should customize scripts in `jenkins/`, keeping the overall structure intact.)

#### Repository Structure End

Those are all of the files needed to add Jenkins pipeline support to a standard
Rails app structure, copy them to your git repo and add a Blue Ocean pipeline
for your GitHub repository in order to begin using the pipeline!

### Common Rails 5 upgrade issues

##### Rails 5 requires Ruby 2.2 or newer, and Rails 6 requires Ruby 2.5

Since Ruby 2.4 is no longer a supported series, you should upgrade to at least
Ruby 2.5. While it is possible to run Rails 5 on older versions of Ruby, they
are all out of maintenance as of the time of this writing.

The `kingdonb/docker-rvm-support:latest` image now includes `2.5.8`, `2.6.6`,
and `2.7.2`, with `2.6.6` as the default suggested version. Ruby `2.5.8` is new
enough for production use today, but will need to be upgraded again by the end
of the year 2020 in order to remain in a supported series of the Ruby language.

##### No `protected_attributes` since Rails 4

Some of our applications still include a `protected_attributes` gem, this has
been deprecated since the beginning of Rails 4 and is now hard failing in the
latest Rails 5 releases. Remove this gem from your Gemfile and mitigate any
uses of the `protected_attributes` gem in your controller code.

Strings to look for in your code indicating use of `protected_attributes` is
currently in use there include:

* `attr_accessible` and `attr_protected`
* `without_protection`
* `mass_assignment_sanitizer`

Mitigations will vary, but suffice it to say the mitigation applied must ensure
those keywords will not appear in uncommented parts of the source code anymore.

Newer versions of Rails have deprecated the protected attributes pattern in
favor of `StrongParameters`, which uses `params.require` and `params.permit`.

##### Pin a version of `rails`, `activerecord-oracle_enhanced-adapter`, ...

The correct version pin for Rails 5.2+ and ActiveRecord with Oracle support is:

```
gem 'rails', '~> 5.0'
gem 'activerecord-oracle_enhanced-adapter', '~> 5.0'
```

If you had pinned a different version for compatibility with another version
of Rails, then you can now re-set those version pins to ensure compatibility
with Rails 5. Pinning this driver to a different version may cause problems.
(Previous versions did not always match the Rails version, but this has been
[normalized in the Oracle adapter][] for ActiveRecord in Rails 5.2 and up.)

With any updated version pins in place, and with Rails gem pinned, you should
be able to run `bundle update` and get a current version of all dependencies.

Use `bundle outdated` and [bundle audit][] in order to verify that you do not
have any remaining version pins unexpectedly holding back your important gem
updates.

If you are not using the `activerecord_oracle_enhanced-adapter` or `ruby-oci8`
gems, then this does not apply to you, although you will still need to bump the
Rails pin in order to run `bundle update`, upgrading `Gemfile.lock` to Rails 5.
The Oracle driver is mostly used in APIs, and isn't found in front-end apps.

##### Pin a version of `rspec`

Also worthy of note, `gem 'rspec', '~> 4.0'` has been out since May, and now
removes support for Rails versions `< 5.0`, so once you are sure the upgrade
succeeded, you may consider pinning the RSpec gem to a newer version too!

For now, I have done this instead (with the intention to maintain the ability
to roll back to the earlier Rails version quickly if needed in case of issue):

```
gem 'rspec-rails', '~> 3.0'
```

##### Sprockets now requires a `manifest.js`

If you are not upgrading to Webpacker, then Sprockets may still need some new
configuration as it will tell you when you try running `rails server` on any
application which has been through this upgrade. Details about upgrading your
`sprockets` Rails asset pipeline to the current version are [covered here][].

Run `rails server` to know if you need this change, in general when upgrading
from Rails 4 to 5 you do need it. The error message provides this sensible
default which you can add to your repo at `app/assets/config/manifest.js`:

```javascript
//= link_tree ../images
//= link_directory ../javascripts .js
//= link_directory ../stylesheets .css
```

Also remove `config.assets.precompile` from `config/initializers/assets.rb`,
as Eileen explains in the 2015 blog post linked above ("[covered here][]").

##### `before_filter` changes to `before_action`

The `before_filter` expression is the same as `before_action`, but if you used
`before_filter` in Rails 4, this syntax was deprecated in Rails 5 and removed
in Rails 5.1. Wherever you find `before_filter`, change it to `before_action`.

The same goes for `skip_before_filter` -> `skip_before_action`.

##### Refresh the `bin/` directory of your app

Once the latest version of Rails 5 is installed, run `rails app:update:bin` to
get the latest versions of any default bin stubs, since these have changed and
some of yours may be out of date. To prevent any problems related to outdated
binstubs, you can run `gem update --system` and `bundle clean --force` to
remove any outdated gems that are not used in your project.

(Careful, if you are using a shared global gemset across many projects, this
step can cause problems with those other projects. Before doing this, make sure
you are prepared to upgrade them, too.)

##### `bundle update --bundler`

There have been some incompatible changes made in Bundler, as of today most of
our devs and projects are still on Bundler 1. As of Ruby 2.6, with Rails 5, now
there remains no reason to stay on the older version of Bundler. Ensure your
development environment's gemset is on the latest version of bundler by running
`bundle update --bundler` or `gem install bundler`. Even if you are only ready
for upgrading to Ruby 2.5 for now, you should opt in to the newer version of
bundler so all our projects will be running a same, current, supported version.

#### Health Checks

Running your app on Kubernetes generally requires adhering to some new best
practices that might not already be in your playbook. To add support for health
checking to your application, a good first step is to add a ping endpoint in
the application's `config/routes.rb` file, as in:

```ruby
  get '/ping', to: proc { [200, {}, ['']] }
```

This approach differs in some valuable ways: first it can skip over Rails
middleware for controllers and views, meaning it can trigger fewer (or no) log
messages. This is particularly valuable because in Kubernetes, more frequent
health checking can be applied to speed the progression of rollouts for new
deploys, and also lessens the likelihood that requests are sent to a service
that wasn't actually ready to accept a connection.

Use `lograge` in your Gemfile to further decrease the amount of log spam and
increase the density of information presented in your application's console.

#### `jenkins/*.sh`

A number of scripts are provided for use in the Jenkinsfile and Dockerfile,
they are parameterized such that they generally do not need to be modified.

The files `docker-*.sh` are written with a `#!/bin/sh` shebang to match the
image that is expected to run them, `docker.io/docker:19`, which provides only
`sh` and doesn't include a full `bash` interpreter. They are intentionally very
simple so they are better able to be modified safely in any given project when
necessary, to support additional image targets or specialized custom workflows.

The remaining scripts are for the most part expected to run in the application
container, which will have a full `bash`, so they can use convenience features
such as `set -euo pipefail` and builtins like `[[`, the better `test` or `[`.

The defaults provided here are meant to be specialized enough to support the
most common developer workflows without customization, but may be customized.

If specialized containers are needed in the pipeline, they can also be included
here for use inside of the `Jenkinsfile`.

* `docker-pod.yaml` - A Kubernetes pod definition used to connect Jenkins to the host node's Docker daemon by mounting `/var/run/docker.sock`, (this is the most straightforward, easiest and also most flexible way. Take caution who is allowed to start Jenkins jobs when running this way, sandbox escapes are certainly possible.)
* `docker-build.sh` - call `docker build` in a specific way that supports our application (here you can pass any buildkit directives needed like `--ssh=default` for inclusion of ssh keys at build time, or any special instructions related to image caching as needed such as `--no-cache`.)
* `runasroot-dependencies.sh` - Called in `Dockerfile`, a script that runs as root. For installing system dependencies from upstream distribution packages (apk, yum or apt).
* `docker-push.sh` - For continuous delivery in dev, a uniquely tagged image based on the Git Commit SHA is pushed whenever a build succeeds (this push happens in parallel with CI, and so may result in eg. early "dev" canary deployment promotion, regardless of any CI test success or failure.)
* `image-tag.sh` - On success of the CI job, a semantic image tag is written based on the git branch label and SHA, or git tag. This script was adapted from [an example provided by our friends at Weaveworks][] to run in plain `sh` shell; it reads output from git commands to generate an appropriate docker image tag based on the git branch or tag.
* `docker-hub-tag-success-push.sh` - This script runs in the final "Push" step, to re-tag the image `repo-host/repo/project:12abcd34` as `repo-host/repo/project:{image-tag}` and push the image tag to the remote image repository, published for downstream consumers.
* `rvm-bundle-cache-build.sh` - Called in `Dockerfile`, this script invokes rvm and handles the heavy lifting of `bundle install` utilizing the buildkit cache volume provider.
* `rake-ci.sh` - This script is run as the `jenkins` user in the `test` container, as specified by the *Test* stage of `Jenkinsfile`. It need not actually run `rake ci`, but this is by default connected to a `rake` task that is created in `lib/tasks/ci.rake`, where testing manifests and launch routines can be centralized.
* `lib/tasks/ci.rake` - We are using `rake ci` as a standard gateway to CI tests such that there is traceability for making policy decisions about testing, and agreement can be maintained regarding what tests are run on a given milestone, or what tests were expected to pass for every promoted release.

Repo admins are meant to modify the default `ci:test` task that `rake ci` defers to in `lib/tasks/ci.rake`, so that whatever tests are important for your PR validation run there.

If some tests take too long and it is holding up progress, then those tests should perhaps not run in `rake ci`. A good guideline for tests that are too large says integration tests which run to completion on each commit should report feedback within maximum about 5 minutes are the most valuable. Since baseline for building a new image may inevitably take up at least a minute (or two) in this cycle, teams should strive to have all CI tests execute in under about 3 minutes.

Parallelism should be taken advantage of to maintain this property if needed, as longer cycle times will severely hinder quick iteration. This is only a guideline, if your important tests necessarily take longer than 3-5 minutes then you should still run them in CI, (but do consider if there may be ways to make them slimmer.)

### End

[covered here]: https://eileencodes.com/posts/the-sprockets-4-manifest/
[normalized in the Oracle adapter]: https://github.com/rsim/oracle-enhanced#rails-52
[bundle audit]: https://github.com/rubysec/bundler-audit
[an example provided by our friends at Weaveworks]: https://github.com/weaveworks/wksctl/blob/78cf6e57cfc28fc720b6ddfe6bfc1da739e4c759/tools/image-tag
