# app.rb
require 'sinatra'
require 'json'
require 'net/http'
require 'uri'

class TwilioRecordingsHandler < Sinatra::Base

  post '/' do

    add_ons = JSON.parse params[:AddOns]
    status = add_ons['status']
    if status != "successful"
      message = add_ons['message']
      code = add_ons['code']
      p "Error #{code}: #{message}"
      return
    end

    vb_results = add_ons['results']['voicebase_transcription']
    if !vb_results.nil?
      # http S3 url invalid cert workaround
      trans_url = vb_results['payload'][0]['url'].gsub(/^https/, "http")
      recording_link = vb_results['links']['Recording']

      uri = URI.parse trans_url
      res = Net::HTTP.get uri
      res_body = JSON.parse res
      transcripts = res_body['media']['transcripts']['text']
      p "Voicebase Transcription: #{transcripts}"
    end

    ibm_results = add_ons['results']['ibm_watson_speechtotext']
    if !ibm_results.nil?
      # http S3 url invalid cert workaround
      trans_url = ibm_results['payload'][0]['url'].gsub(/^https/, "http")
      recording_link = ibm_results['links']['Recording']

      uri = URI.parse trans_url
      res = Net::HTTP.get uri
      res_body = JSON.parse res
      results = res_body['results'][0]['results']
      transcripts = ""
      results.each do |result|
        transcripts += result['alternatives'][0]['transcript'] + " "
      end
      p "IBM Transcription: #{transcripts}"
    end

  end

end
