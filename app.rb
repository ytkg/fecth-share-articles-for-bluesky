require 'bundler/inline'
require 'dotenv/load'

gemfile do
  source 'https://rubygems.org'
  gem 'bskyrb'
  gem 'dotenv'
end

module Bskyrb
  class RecordManager
    # def get_skyline(n)
    #   endpoint = XRPC::EasyEndpoint.new(session.pds, "app.bsky.feed.getTimeline", authenticated: true)
    #   endpoint.authenticate(session.access_token)
    #   hydrate_feed endpoint.get(limit: n), Bskyrb::AppBskyFeedGettimeline::GetTimeline::Output
    # end
    def get_skyline(n, cursor = nil)
      endpoint = XRPC::EasyEndpoint.new(session.pds, 'app.bsky.feed.getTimeline', authenticated: true)
      endpoint.authenticate(session.access_token)
      response = endpoint.get(limit: n, cursor: cursor)
      [hydrate_feed(response, Bskyrb::AppBskyFeedGettimeline::GetTimeline::Output), response['cursor']]
    end
  end
end

# record:
#   {"text"=>"Our Plan for a Sustainably Open Social Network - Bluesky https://blueskyweb.xyz/blog/7-05-2023-business-plan miteru",
#    "$type"=>"app.bsky.feed.post",
#    "langs"=>["ja"],
#    "facets"=>
#     [{"index"=>{"byteEnd"=>108, "byteStart"=>57},
#       "features"=>[{"uri"=>"https://blueskyweb.xyz/blog/7-05-2023-business-plan", "$type"=>"app.bsky.richtext.facet#link"}]}],
#    "createdAt"=>"2023-07-06T09:11:16.670Z"}
def get_urls(record)
  urls = []

  # facets:
  #   [{"index"=>{"byteEnd"=>102, "byteStart"=>72}, "features"=>[{"uri"=>"https://go-proverbs.github.io/", "$type"=>"app.bsky.richtext.facet#link"}]},
  #    {"index"=>{"byteEnd"=>369, "byteStart"=>321},
  #     "features"=>[{"uri"=>"https://go.dev/ref/mod#minimal-version-selection", "$type"=>"app.bsky.richtext.facet#link"}]}]
  if record['facets']
    record['facets'].each do |facet|
      facet['features'].each do |feature|
        urls.push(feature['uri']) if feature['$type'] == 'app.bsky.richtext.facet#link'
      end
    end
  end

  # entities:
  #   [{"type"=>"link", "index"=>{"end"=>238, "start"=>197}, "value"=>"https://github.com/gibbok/typescript-book"}]
  if record['entities']
    record['entities'].each do |entity|
      urls.push(entity['value']) if entity['type'] == 'link'
    end
  end

  urls
end

credentials = Bskyrb::Credentials.new(ENV['BLUESKY_USERNAME'], ENV['BLUESKY_PASSWORD'])
session = Bskyrb::Session.new(credentials, 'https://bsky.social')
bsky = Bskyrb::RecordManager.new(session)

cursor = ''
urls = []

100.times do
  timeline, cursor = bsky.get_skyline(100, cursor)

  timeline.feed.each do |row|
    post = row.post
    record = post.record
    text = record['text']
    urls.concat(get_urls(record))
  end

  print '.'
end

puts

pp Hash[urls.tally.select { |_, c| c >= 2}.sort_by { |_, c| -c }]
