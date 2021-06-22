require 'stripe'
require 'sinatra'
require 'dotenv'
require 'httparty'
require 'pry'

# Copy the .env.example in the root into a .env file in this folder

Dotenv.load
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

set :static, true
set :public_folder, File.join(File.dirname(__FILE__), '../client')
set :port, 4242

get '/' do
  # Display checkout page
  content_type 'text/html'
  send_file File.join(settings.public_folder, 'index.html')
end

def calculate_order_amount(isDonating)
  # Replace this constant with a calculation of the order's amount
  # Calculate the order total on the server to prevent
  # people from directly manipulating the amount on the client
  isDonating ? 1400 : 1354
end

post '/create-payment-intent' do
  content_type 'application/json'
  data = JSON.parse(request.body.read)

  # Required if we want to transfer part of the payment as a donation
  # A transfer group is a unique ID that lets you associate transfers with the original payment
  transfer_group = 'group_' + rand(10_000).to_s

  # Create a PaymentIntent with the order amount and currency
  payment_intent = Stripe::PaymentIntent.create(
    amount: calculate_order_amount(data['items']),
    currency: data['currency'],
    transfer_group: transfer_group
  )

  # Send publishable key and PaymentIntent details to client
  {
    publicKey: ENV['STRIPE_PUBLISHABLE_KEY'],
    paymentIntent: payment_intent
  }.to_json
end

#
# TODO: Add /update-payment-intent endpoint here
#

#
# TODO: Add /webhook endpoint here
#

def verify_webhook
  # Use webhooks to receive information about asynchronous payment events.
  # For more about our webhook events check out https://stripe.com/docs/webhooks.
  webhook_secret = ENV['STRIPE_WEBHOOK_SECRET']
  payload = request.body.read
  if !webhook_secret.empty?
    # Retrieve the event by verifying the signature using the raw body and secret if webhook signing is configured.
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    event = nil

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, webhook_secret
      )
    rescue JSON::ParserError => e
      # Invalid payload
      return
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      puts '⚠️  Webhook signature verification failed.'
      return
    end
  else
    data = JSON.parse(payload, symbolize_names: true)
    event = Stripe::Event.construct_from(data)
  end

  return event, data
end