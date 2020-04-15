#
# Copyright 2020 YOUR NAME
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

name "vulcan"
description "the steps required to install the vulcan application"

license :project_license
skip_transitive_dependency_licensing true

source path: File.expand_path('../../../../', project.filepath),
        options: { exclude: [ "omnibus/vendor" ] }

# vulcan dependencies/components
if windows?
  dependency "ruby-windows-system-libraries"
end
dependency "bundler"
dependency "nokogiri"
dependency "nodejs-binary"
dependency "postgresql11"

build do
  env = with_standard_compiler_flags(with_embedded_path)
  # Enhance path to include nodejs for asset precompilation
  env["PATH"] += "#{env["PATH"]}:#{install_dir}/embedded/nodejs/bin"
  # Set a generic SECRET_KEY_BASE to avoid errors on asset precompilation
  env["SECRET_KEY_BASE"] = 'fake, real one generated on app install'

  bundle_without = %w(development test)
  bundle "config build.pg --with-pg-config=#{install_dir}/embedded/postgresql/11/bin/pg_config", env: env

  bundle "package --all --no-install"

  bundle "install" \
        " --jobs #{workers}" \
        " --retry 3" \
        " --without #{bundle_without.join(' ')}",
        env: env

  bundle "exec rake assets:precompile", env: env.merge('RAILS_ENV' => 'production')

  sync project_dir, "#{install_dir}/embedded/service/vulcan/", exclude: %w(
    .byebug_history
    .git
    .gitignore
    .gitlab-ci.yml
    .rspec
    CNAME
    Dockerfile
    embedded
    docker-compose.yml
    _config.yml
    spec
    omnibus
    .rubocop.yml
    app/assets
    vendor/assets
    tmp
  )
end
