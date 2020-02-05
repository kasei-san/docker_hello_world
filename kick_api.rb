require 'net/https'
require 'uri'

BRANCH_NAME = ARGV[0]
CODEBUILD_RESOLVED_SOURCE_VERSION = ARGV[1]

uri = URI.parse("https://0ym4rbvub6.execute-api.us-east-1.amazonaws.com/production/create?branch_name=#{BRANCH_NAME}&commit_hash=#{CODEBUILD_RESOLVED_SOURCE_VERSION}")
puts "Kick API: #{uri.to_s}"

res = Net::HTTP.get_response(uri)

puts "Responce code: #{res.code}"
puts "Responce body: #{res.body}"
res.value # 200以外なら例外を返す
