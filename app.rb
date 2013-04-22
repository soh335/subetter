require 'sinatra'
require "sinatra/reloader" if development?
require 'sinatra/flash'
require 'omniauth'
require 'omniauth-tumblr'
require 'omniauth-twitter'
require 'twitter'
require 'tumblife'
require 'pp'
require 'rack/session/dalli'
require 'dalli'
require 'memcachier'

use Rack::Session::Dalli, :cache => Dalli::Client.new, :expire_after => 60 * 60 * 24 * 3

TWITTER_CONSUMER_KEY        = ENV["TWITTER_CONSUMER_KEY"]
TWITTER_CONSUMER_SECRET_KEY = ENV["TWITTER_CONSUMER_SECRET_KEY"]

TUMBLR_CONSUMER_KEY         = ENV["TUMBLR_CONSUMER_KEY"]
TUMBLR_CONSUMER_SECRET_KEY  = ENV["TUMBLR_CONSUMER_SECRET_KEY"]
TUMBLR_OAUTH_TOKEN          = ENV["TUMBLR_OAUTH_TOKEN"]
TUMBLR_OAUTH_TOKEN_SECRET   = ENV["TUMBLR_OAUTH_TOKEN_SECRET"]

use OmniAuth::Builder do
  provider :tumblr,  TUMBLR_CONSUMER_KEY,  TUMBLR_CONSUMER_SECRET_KEY
  provider :twitter, TWITTER_CONSUMER_KEY, TWITTER_CONSUMER_SECRET_KEY
end

Twitter.configure do |config|
  config.consumer_key    = TWITTER_CONSUMER_KEY
  config.consumer_secret = TWITTER_CONSUMER_SECRET_KEY
end

Tumblife.configure do |config|
  config.consumer_key       = TUMBLR_CONSUMER_KEY
  config.consumer_secret    = TUMBLR_CONSUMER_SECRET_KEY
  config.oauth_token        = TUMBLR_OAUTH_TOKEN
  config.oauth_token_secret = TUMBLR_OAUTH_TOKEN_SECRET
end

class User
  attr_reader :twtter_access_token, :twitter_access_token_secret

  def initialize(session)
    @twitter_access_token        = session['twitter_access_token']
    @twitter_access_token_secret = session['twitter_access_token_secret']
  end

  def twitter_login?
    @twitter_access_token && @twitter_access_token_secret
  end

  def post(id)
    twitter = twitter_client()
    tumblr  = tumblr_client()

    oembed = twitter.oembed(id)
    tumblr.text('subetter.tumblr.com', :body => oembed.html, :slug => id)
  end

  def twitter_client
    Twitter::Client.new(
      :oauth_token        => @twitter_access_token,
      :oauth_token_secret => @twitter_access_token_secret,
    )
  end

  def tumblr_client
    Tumblife.client
  end
end

before do
  @user = User.new(session)
end

get '/' do
  @messages = [flash[:msg]]
  erb :index
end

post '/post' do
  begin
    ret = @user.post(request.params['id'])
    flash[:msg] = ret["id"] ? "success to post" : "error"
  rescue Twitter::Error => error
    flash[:msg] = error.to_s
  rescue => error
    flash[:msg] = error.to_s
  end

  redirect '/'
end

get '/auth/:name/callback' do
  @auth = request.env['omniauth.auth']
  session[ @auth['provider'] + '_access_token'] = @auth['credentials']['token']
  session[ @auth['provider'] + '_access_token_secret'] = @auth['credentials']['secret']

  redirect '/'
end

get '/logout' do

  ["twitter"].each do |name|
    session[ name + '_access_token']        = nil
    session[ name + '_access_token_secret'] = nil
  end

  redirect '/'
end

__END__

@@ layout
<html>
<head>
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
</div>
<div>
<% unless @user.twitter_login? then %>
<a href="/auth/twitter">login twitter</a>
<% end %>
</div>
<div>
<% if @user.twitter_login? then %>
<form method="post" action="/post">
<input type="text" name="id" />
<input type="submit" value="post" />
</form>
<a href="/logout">logout</a>
<% end %>
</div>
