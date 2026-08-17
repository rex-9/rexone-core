module MessageService
  class Base
    class << self
      def translate(key, **options)
        I18n.t(key, **options)
      end
      alias_method :t, :translate
    end
  end
end
