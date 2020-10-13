## Jenkinsfile for Rails 5

To bootstrap your Rails application with a Jenkins CI pipeline, copy everything
from this repo and add it to your app repo. If you are upgrading to Rails 5,
the notes that follow may provide valuable assistance to support your efforts!

#### `Jenkinsfile`

There is some front-matter in the Jenkinsfile which must be customized for your
application's container registry or image repository, but otherwise the files
in this repo are meant to be copied into your project unmodified to support a
Jenkins pipeline that builds and tests your application on Jenkins/Kubernetes.

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
here for use inside of the `Jenkinsile`.

* `docker-pod.yaml` - A Kubernetes pod definition used to connect Jenkins to the host node's Docker daemon by mounting `/var/run/docker.sock`, (this is the most straightforward, easiest and also most flexible way. Take caution who is allowed to start Jenkins jobs when running this way, sandbox escapes are certainly possible.)
* `docker-build.sh` - call `docker build` in a specific way that supports our application (here you can pass any buildkit directives needed like `--ssh=default` for inclusion of ssh keys at build time, or any special instructions related to image caching as needed such as `--no-cache`.)
* `runasroot-dependencies.sh` - Called in `Dockerfile`, a script that runs as root. For installing system dependencies from upstream distribution packages (apk, yum or apt).
* `docker-push.sh` - For continuous delivery in dev, a uniquely tagged image based on the Git Commit SHA is pushed whenever a build succeeds (this happens in parallel with CI, and so, regardless of any CI test success or failure.)
* `image-tag.sh` - On success of the CI job, a semantic image tag is generated based on the branch revision or tag. This script reads output from git to generate that tag string.
* `docker-hub-tag-success-push.sh` - This script runs in the final "Push" step, to re-tag the image `repo-host/repo/project:12abcd34` as `repo-host/repo/project:{image-tag}` and push the image tag to the remote image repository, published for downstream consumers.
* `rvm-bundle-cache-build.sh` - Called in `Dockerfile`, this script invokes rvm and handles the heavy lifting of `bundle install` utilizing the buildkit cache volume provider.
* `rake-ci.sh` - This script is run as the `jenkins` user in the `test` container, as specified by the *Test* stage of `Jenkinsfile`. It need not actually run `rake ci`, but this is connected to a `rake` task that we create in `lib/tasks/ci.rake` for the benefit of centralization.
* `lib/tasks/ci.rake` - Using `rake ci` as a standard gateway to CI tests provides traceability and uniformity so auditors and developers alike can codify policy decisions and agree about what tests were ran on a given build, or what tests were expected to pass for every promoted release. Modify the default `ci:test` task that `rake ci` defines in this file, so that it runs whatever tests are important for your build validation.

If some tests take too long and it is holding up the build, then those tests should not run in `rake ci`. A good guideline for tests that are too large says that integration tests which run to completion on each iteration and report feedback within a total of 5 minutes are the most valuable for CI. Since building the test image itself will inevitably take up at least a minute or two inside of this cycle, you should strive to have all your validation tests execute to completion and report results in less than about 3 minutes.

This is only a guideline, if your important tests take longer than 3 minutes then you should run them in CI, but also consider working on ways to make them slimmer.

### End

[covered here]: https://eileencodes.com/posts/the-sprockets-4-manifest/
[normalized in the Oracle adapter]: https://github.com/rsim/oracle-enhanced#rails-52
[bundle audit]: https://github.com/rubysec/bundler-audit
