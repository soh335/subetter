require 'sinatra'
require "sinatra/reloader" if development?
require 'sinatra/flash'
require 'twitter'
require 'tumblife'
require 'pp'
require 'rack/session/cookie'
set :erb, :escape_html => true

use Rack::Session::Cookie, :expire_after => 60 * 60 * 24 * 3,
                           :secret       => ENV["SESSION_SECRET"]

Twitter.configure do |config|
  config.consumer_key    = ENV["TWITTER_CONSUMER_KEY"]
  config.consumer_secret = ENV["TWITTER_CONSUMER_SECRET_KEY"]
  config.bearer_token    = ENV["TWITTER_BEARER_TOKEN"]
end

Tumblife.configure do |config|
  config.consumer_key       = ENV["TUMBLR_CONSUMER_KEY"]
  config.consumer_secret    = ENV["TUMBLR_CONSUMER_SECRET_KEY"]
  config.oauth_token        = ENV["TUMBLR_OAUTH_TOKEN"]
  config.oauth_token_secret = ENV["TUMBLR_OAUTH_TOKEN_SECRET"]
end

configure :production do
  require 'newrelic_rpm'
end

get '/' do
  @messages = [flash[:msg]]
  @is_success = flash[:is_success]
  erb :index
end

post '/post' do
  begin
    id = request.params["id"]
    tumblr = Tumblife.client
    twitter = Twitter::Client.new
    oembed = twitter.oembed(id)
    ret = tumblr.text('subetter.tumblr.com', :body => oembed.html, :slug => id)
    if ret["id"]
      flash[:is_success] = true
    end
  rescue Twitter::Error => error
    flash[:msg] = error.to_s
  rescue => error
    flash[:msg] = error.to_s
  end

  redirect '/'
end

__END__

@@ layout
<html>
<head>
<title>subetter</title>
</head>
<body>
<div>
<%= yield %>
</div>
</body>
</html>

@@ index
<% @messages.each do |msg| %>
<div><%= msg %></div>
<% end %>
<% if @is_success %>
success to post. <br>check <a href="http://subetter.tumblr.com/">subetter.tumblr.com</a>
<% end %>
</div>
<div>
+ subetter +<br>
<br>
<form method="post" action="/post">
tweet_id: <input type="text" name="id" />
<input type="submit" value="post" />
</form>
enjoy.
</div>
