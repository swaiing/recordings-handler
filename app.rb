# app.rb
require 'sinatra'
require 'json'
require 'net/http'
require 'uri'
require 'twilio-ruby'

class TwilioRecordingsHandler < Sinatra::Base

  helpers do

    def handlePost(notification_number, add_ons)
      transcripts = ""
      vb_results = add_ons['results']['voicebase_transcription']
      if !vb_results.nil?
        recording_link = retrieveRecordingLink vb_results
        response_body = retrieveAnalysisResults vb_results
        transcripts += "VoiceBase: "
        transcripts += response_body['media']['transcripts']['text']
      end

      ibm_results = add_ons['results']['ibm_watson_speechtotext']
      if !ibm_results.nil?
        recording_link = retrieveRecordingLink ibm_results
        response_body = retrieveAnalysisResults ibm_results
        transcripts += "IBM: "
        results = response_body['results'][0]['results']
        results.each do |result|
          transcripts += result['alternatives'][0]['transcript'] + " "
        end
      end
      p transcripts

      sendSms notification_number, transcripts
    end

    def retrieveAnalysisResults(results)
        url = results['payload'][0]['url']
        response = ""

        # for API resource fix
        if url.include? "api.twilio.com"
          uri = URI.parse url
          Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
              req = Net::HTTP::Get.new uri.request_uri
              req.basic_auth ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
              response = http.request req
              p "API resource: #{response.body}"
          end
          
        # for invalid S3
        else
          trans_url = url.gsub(/^https/, "http")
          uri = URI.parse trans_url
          response = Net::HTTP.get uri
          p "Invalid S3 resource: #{response}"
        end

        JSON.parse response
    end

    def retrieveRecordingLink(results)
        results['links']['Recording']
    end

    def sendSms(notification_number, body)
      if notification_number.nil?
        p "Error sending SMS: No notification number given"
        return
      end

      # TODO: move to class instantiation
      account_sid = ENV['TWILIO_ACCOUNT_SID']
      auth_token = ENV['TWILIO_AUTH_TOKEN']
      from_number = ENV['TWILIO_NUMBER']
      @client = Twilio::REST::Client.new account_sid, auth_token

      # send SMS
      @client.account.messages.create({
        :from => from_number,
        :to => notification_number,
        :body => body
      })
    end

  end

  post '/' do
    # get AddOns, form encoded in POST body
    add_ons = JSON.parse params[:AddOns]
    status = add_ons['status']
    if status != "successful"
      message = add_ons['message']
      code = add_ons['code']
      p "Error #{code} : #{message}"
      return
    end

    # get number param in GET
    notification_number = params[:number]
    p "Notification Number: #{notification_number}"

    # process transcription analysis
    handlePost notification_number, add_ons
  end

end
