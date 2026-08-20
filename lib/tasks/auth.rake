# frozen_string_literal: true

namespace :vulcan do
  namespace :auth do
    desc 'Rename a provider key on identities + users (e.g. legacy oidc → okta). ' \
         'Register the new callback URI at the IdP first.'
    task :rename_provider, %i[old_name new_name] => :environment do |_t, args|
      old_name = args[:old_name].to_s.strip
      new_name = args[:new_name].to_s.strip

      if old_name.empty? || new_name.empty?
        puts 'Usage: rails vulcan:auth:rename_provider[old,new]'
        puts 'Both old and new provider names are required.'
        next
      end

      identities_count = Identity.where(provider: old_name).update_all(provider: new_name)
      users_count = User.where(provider: old_name).update_all(provider: new_name)

      puts "Renamed provider '#{old_name}' → '#{new_name}': #{identities_count} identity rows, #{users_count} user rows."
    end
  end
end
