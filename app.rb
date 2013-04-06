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

use OmniAuth::Builder do
  provider :tumblr,  TUMBLR_CONSUMER_KEY,  TUMBLR_CONSUMER_SECRET_KEY
  provider :twitter, TWITTER_CONSUMER_KEY, TWITTER_CONSUMER_SECRET_KEY
end

Twitter.configure do |config|
  config.consumer_key    = TWITTER_CONSUMER_KEY
  config.consumer_secret = TWITTER_CONSUMER_SECRET_KEY
end

Tumblife.configure do |config|
  config.consumer_key    = TUMBLR_CONSUMER_KEY
  config.consumer_secret = TUMBLR_CONSUMER_SECRET_KEY
end

class User
  attr_reader :twtter_access_token,
    :twitter_access_token_secret,
    :tumblr_access_token,
    :tumblr_access_token_secret,
    :tumblr_subetter

  def initialize(session)
    @twitter_access_token        = session['twitter_access_token']
    @twitter_access_token_secret = session['twitter_access_token_secret']
    @tumblr_access_token         = session['tumblr_access_token']
    @tumblr_access_token_secret  = session['tumblr_access_token_secret']
    @tumblr_subetter             = session['tumblr_subetter']
  end

  def twitter_login?
    @twitter_access_token && @twitter_access_token_secret
  end

  def tumblr_login?
    @tumblr_access_token && @tumblr_access_token_secret
  end

  def post(id)
    twitter = twitter_client()
    tumblr  = tumblr_client()

    oembed = twitter.oembed(id)
    tumblr.text('subetter.tumblr.com', :body => oembed.html)
  end

  def twitter_client
    Twitter::Client.new(
      :oauth_token        => @twitter_access_token,
      :oauth_token_secret => @twitter_access_token_secret,
    )
  end

  def tumblr_client
    Tumblife.client(
      :oauth_token        => @tumblr_access_token,
      :oauth_token_secret => @tumblr_access_token_secret
    )
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

  if @auth['provider'] == "tumblr" then
    session['tumblr_subetter'] =
      @auth['extra']["raw_info"]["blogs"].select { |b| b.url == "http://subetter.tumblr.com" } ? 1 : 0
  end

  redirect '/'
end

get '/logout' do

  ["twitter", "tumblr"].each do |name|
    session[ name + '_access_token']        = nil
    session[ name + '_access_token_secret'] = nil
  end

  session['tumblr_subetter'] = nil

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
<% unless @user.tumblr_login? then %>
<a href="/auth/tumblr">login tumblr</a>
<% end %>
</div>
<div>
<% unless @user.twitter_login? then %>
<a href="/auth/twitter">login twitter</a>
<% end %>
</div>
<div>
<% if @user.tumblr_login? and @user.twitter_login? then %>
<form method="post" action="/post">
<input type="text" name="id" />
<input type="submit" value="post" />
</form>
<% end %>
<% if @user.tumblr_login? or @user.twitter_login? then %>
<a href="/logout">logout</a>
<% end %>
</div>
