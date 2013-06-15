require 'sinatra'
require "sinatra/reloader" if development?
require 'sinatra/flash'
require 'twitter'
require 'pp'
require 'rack/session/cookie'
set :erb, :escape_html => true

use Rack::Session::Cookie, :expire_after => 60 * 60 * 24 * 3,
                           :secret       => ENV["SESSION_SECRET"]

configure do
  RETWEET_CLIENT = Twitter::Client.new(
    consumer_key:       ENV["TWITTER_CONSUMER_KEY"],
    consumer_secret:    ENV["TWITTER_CONSUMER_SECRET_KEY"],
    oauth_token:        ENV["TWITTER_ACCESS_TOKEN"],
    oauth_token_secret: ENV["TWITTER_ACCESS_TOKEN_SECRET"]
  )
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
    tweet = RETWEET_CLIENT.retweet(id.to_i)
    if tweet
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
success to post. <br>check <a href="https://twitter.com/subetter_san">subetter_san</a>
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
