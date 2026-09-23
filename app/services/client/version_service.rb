# app/services/version_service.rb

class Client::VersionService
  EMPTY_CATALOG = {
    id: nil,
    number: nil,
    title: nil,
    description: nil,
    status: nil,
    released_at: nil
  }.freeze

  Result = Data.define(:latest, :update_required, :must_update, :skip_premium, :store_url)

  class << self
    def check(version:, platform:, build_number: nil)
      build_num = build_number.presence
      if build_num.blank? && version.to_s.include?("+")
        build_num = version.to_s.split("+").second
      end
      parsed_build = Integer(build_num, exception: false) if build_num.present?

      latest = latest_live
      Result.new(
        latest: latest,
        update_required: update_required?(client_number: version, latest: latest, platform: platform, build_number: parsed_build),
        must_update: must_update?(client_number: version, platform: platform, build_number: parsed_build),
        skip_premium: skip_premium?(client_number: version, latest: latest, platform: platform, build_number: parsed_build),
        store_url: store_url_for(platform)
      )
    end

    def latest_live
      Client::Version.live.max_by { |version| Gem::Version.new(version.number) }
    end

    def update_required?(client_number:, latest:, platform: nil, build_number: nil)
      client_version = parse_semver(client_number)
      return false if client_version.blank? || latest.blank?

      latest_version = Gem::Version.new(latest.number)
      return true if client_version < latest_version

      if client_version == latest_version && build_number.present?
        target_build = platform_build_number(latest, platform)
        return true if target_build.present? && build_number < target_build
      end

      false
    end

    def must_update?(client_number:, platform: nil, build_number: nil)
      client_version = parse_semver(client_number)
      latest = latest_live
      return false if client_version.blank? || latest.blank? || !latest.is_force_update

      latest_version = Gem::Version.new(latest.number)
      return true if client_version < latest_version

      if client_version == latest_version && build_number.present?
        target_build = platform_build_number(latest, platform)
        return true if target_build.present? && build_number < target_build
      end

      false
    end

    def skip_premium?(client_number:, latest:, platform: nil, build_number: nil)
      client_version = parse_semver(client_number)
      return false if client_version.blank? || latest.blank?

      latest_version = Gem::Version.new(latest.number)
      return true if client_version > latest_version

      if client_version == latest_version && build_number.present?
        target_build = platform_build_number(latest, platform)
        return true if target_build.present? && build_number > target_build
      end

      false
    end

    private

    def platform_build_number(version_record, platform)
      case platform.to_s.downcase
      when AuthConstants::Platform::IOS then version_record.ios_build_number
      when AuthConstants::Platform::ANDROID then version_record.android_build_number
      end
    end

    def store_url_for(platform)
      case platform
      when AuthConstants::Platform::IOS then AppConfig::IOS_STORE_URL.presence
      when AuthConstants::Platform::ANDROID then AppConfig::ANDROID_STORE_URL.presence
      end
    end

    def parse_semver(value)
      return if value.blank?

      semver = value.to_s.split("+").first.strip
      return unless semver.match?(VersionConstants::Number::FORMAT)

      Gem::Version.new(semver)
    end
  end
end
