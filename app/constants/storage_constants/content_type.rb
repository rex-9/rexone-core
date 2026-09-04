# app/constants/storage_constants/content_type.rb

module StorageConstants
  module ContentType
    DEFAULT = "application/octet-stream".freeze

    FOR_EXTENSION = {
      "jpg"  => "image/jpeg",
      "jpeg" => "image/jpeg",
      "png"  => "image/png",
      "gif"  => "image/gif",
      "webp" => "image/webp",
      "svg"  => "image/svg+xml",
      "mp3"  => "audio/mpeg",
      "wav"  => "audio/wav",
      "m4a"  => "audio/mp4",
      "aac"  => "audio/aac",
      "ogg"  => "audio/ogg",
      "flac" => "audio/flac",
      "mp4"  => "video/mp4",
      "mov"  => "video/quicktime",
      "avi"  => "video/x-msvideo",
      "webm" => "video/webm",
      "mkv"  => "video/x-matroska",
      "pdf"  => "application/pdf",
      "doc"  => "application/msword",
      "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "txt"  => "text/plain",
      "rtf"  => "application/rtf"
    }.freeze

    # Canonical extension per media type, for remote sources that expose a
    # content type but no filename extension (for example Google avatar URLs).
    FOR_CONTENT_TYPE = {
      "image/jpeg"      => "jpg",
      "image/png"       => "png",
      "image/gif"       => "gif",
      "image/webp"      => "webp",
      "image/svg+xml"   => "svg",
      "audio/mpeg"      => "mp3",
      "audio/wav"       => "wav",
      "audio/mp4"       => "m4a",
      "audio/aac"       => "aac",
      "audio/ogg"       => "ogg",
      "audio/flac"      => "flac",
      "video/mp4"       => "mp4",
      "video/quicktime" => "mov",
      "video/webm"      => "webm",
      "application/pdf" => "pdf"
    }.freeze

    def self.for_extension(extension)
      FOR_EXTENSION.fetch(extension.to_s.downcase, DEFAULT)
    end

    def self.extension_for(content_type)
      return nil if content_type.blank?

      FOR_CONTENT_TYPE[content_type.to_s.downcase.split(";").first.to_s.strip]
    end
  end
end
