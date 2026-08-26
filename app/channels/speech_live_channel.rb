# app/channels/speech_live_channel.rb

require "base64"

class SpeechLiveChannel < ApplicationCable::Channel
  IDLE_CHECK_SECONDS = 5

  def subscribed
    unless current_user.can?(:create, "speech")
      reject
      return
    end

    stream_from stream_name
    @session = SpeechService::Client.start_live_stt(
      language: params[:language],
      on_event: ->(event) { push_event(event) }
    )
    watch_idle
  end

  def unsubscribed
    teardown
  end

  def audio(data)
    return if @session.nil?

    @session.write_audio(Base64.decode64(data["chunk"].to_s))
  rescue ArgumentError
    nil
  end

  def stop
    teardown
  end

  private

  def stream_name
    "#{SpeechConstants::Live::STREAM_PREFIX}_#{current_user.id}"
  end

  def push_event(event)
    SocketService::Client.broadcast_to_channel(
      channel: stream_name,
      message: event[:text] || event[:error],
      data: event
    )
  end

  def watch_idle
    @idle_thread = Thread.new do
      loop do
        sleep IDLE_CHECK_SECONDS
        break if @teardown
        break if @session.nil?

        teardown if @session.idle?
      end
    end
  end

  def teardown
    return if @teardown

    @teardown = true
    @session&.stop
    @idle_thread&.kill unless Thread.current == @idle_thread
  end
end
