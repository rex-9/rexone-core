# app/services/storage_service/base.rb

module StorageService
  class Base
    def upload(file, options = {})
      raise NotImplementedError, "#{self.class} must implement #upload"
    end

    def delete(identifier, options = {})
      raise NotImplementedError, "#{self.class} must implement #delete"
    end

    def url(identifier, options = {})
      raise NotImplementedError, "#{self.class} must implement #url"
    end

    def move(source, destination, options = {})
      raise NotImplementedError, "#{self.class} must implement #move"
    end

    def copy(source, destination, options = {})
      raise NotImplementedError, "#{self.class} must implement #copy"
    end

    def exists?(identifier)
      raise NotImplementedError, "#{self.class} must implement #exists?"
    end

    def list(prefix = nil)
      raise NotImplementedError, "#{self.class} must implement #list"
    end
  end
end
