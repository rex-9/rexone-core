
require 'aws-sdk-s3'

client = Aws::S3::Client.new(

  region: 'garage',

  endpoint: 'https://storage.zentrydigitalmm.com',

  access_key_id: 'GK71a9101c7dbdd77632b86840',

  secret_access_key: '3429d001c8ed7cef9df3890b030019b83b77ddee51e861f4eb7fa178c1b6fe3c',

  force_path_style: true

)

puts "Testing Garage from external..."

# List buckets

buckets = client.list_buckets

puts "\n📦 Buckets:"

buckets.buckets.each { |b| puts "  ✅ #{b.name}" }

# Upload test file

puts "\n⬆️  Uploading test.txt..."

client.put_object(

  bucket: 'rexone',

  key: 'external-test.txt',

  body: 'Hello from external!',

  content_type: 'text/plain'

)

puts "✅ Uploaded!"

