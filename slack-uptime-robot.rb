#!/usr/bin/ruby

require 'rubygems'
require 'bundler/setup'

require 'slack-ruby-client'
require 'eventmachine'

require 'twilio-ruby'

class SlackUptimeRobot

	def initialize
		@twilio_sid = ENV['TWILIO_SID']
		@twilio_auth_token = ENV['TWILIO_AUTH_TOKEN']
		@twilio_from_phone = ENV['TWILIO_PHONE_NUMBER']			# the FROM phone number you purchased from twilio

		@notify_phone = ENV['TO_PHONE_NUMBER']				# the phone which will receive the SMS
		@slack_token = ENV['SLACK_TOKEN']					# create your bot at https://my.slack.com/services/new/bot

		setupTwilio()
		setupSlack()
	end

	def setupTwilio()
		@twilio = Twilio::REST::Client.new @twilio_sid, @twilio_auth_token
	end

	def sendSMS(msg)
		@twilio.messages.create(
			from: @twilio_from_phone,	
			to: 	@notify_phone,
			body: msg
		)
	end

	def setupSlack()
		Slack.configure do |config|
			config.token = @slack_token
		end

		client = Slack::RealTime::Client.new()

		client.on :hello do
			puts "Successfully connected, welcome '#{client.self.name}' to the '#{client.team.name}' team at https://#{client.team.domain}.slack.com."
			File.write('/app/health', 'up')
		end

		client.on :message do |data|

			puts data.text

			# UptimeRobot sends messages that look like this:
			# Monitor is DOWN: Website ( http://website.com )
			# Monitor is UP: Website ( http://website.com/ ). It was down for 0 minutes and 59 seconds.
			case data.text
			when /^Monitor/ then
				self.sendSMS(data.text)
				client.message channel: data.channel, text: "I've sent a text to #{@notify_phone}"
			end
		end

		client.on :close do |_data|
			puts "Client is about to disconnect"
			File.write('/app/health', 'down')
		end

		client.on :closed do |_data|
			puts "Client has disconnected successfully!"
			File.write('/app/health', 'down')
		end

		client.start!
	end

end

SlackUptimeRobot.new