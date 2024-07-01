require 'settingslogic'

class Settingslogic
  def initialize(hash_or_file = self.class.source, section = nil)
    case hash_or_file
    when nil
      raise Errno::ENOENT, "No file specified as Settingslogic source"
    when Hash
      self.replace hash_or_file
    else
      file_contents = open(hash_or_file).read
      hash = file_contents.empty? ? {} : YAML.load(ERB.new(file_contents).result, aliases: true).to_hash
      if self.class.namespace
        hash = hash[self.class.namespace] or return missing_key("Missing setting '#{self.class.namespace}' in #{hash_or_file}")
      end
      self.replace hash
    end
    @section = section || self.class.source  # so end of error says "in application.yml"
    create_accessors!
  end
end
